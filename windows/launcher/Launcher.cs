using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("WSL Terminal")]
[assembly: System.Reflection.AssemblyProduct("WSL Terminal")]
[assembly: System.Reflection.AssemblyDescription("Ubuntu WSL terminal launcher with a separate Windows app identity")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

namespace WslTerminalLauncher
{
    internal static class Program
    {
        const string AppId = "Local.WSLTerminal";
        static readonly string Local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        static readonly string Assets = Path.Combine(Local, "WSL Terminal");
        static readonly string LogPath = Path.Combine(Assets, "launcher.log");
        static readonly Guid PropertyGuid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
        static readonly Guid StoreGuid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
        static readonly string Executable = Process.GetCurrentProcess().MainModule.FileName;

        [STAThread]
        static int Main(string[] args)
        {
            Directory.CreateDirectory(Assets);
            try
            {
                if (args.Length == 1 && args[0] == "--self-check")
                {
                    using (var small = LoadIcon(32))
                    using (var large = LoadIcon(48))
                    {
                        if (small.Handle == IntPtr.Zero || large.Handle == IntPtr.Zero)
                            throw new InvalidOperationException("Embedded Terminal icon could not be loaded.");
                    }
                    return 0;
                }
                if (args.Length == 2 && args[0] == "--register-shortcut")
                {
                    IPropertyStore store;
                    Guid iid = StoreGuid;
                    Marshal.ThrowExceptionForHR(SHGetPropertyStoreFromParsingName(args[1], IntPtr.Zero, 2, ref iid, out store));
                    try { SetIdentity(store); Marshal.ThrowExceptionForHR(store.Commit()); }
                    finally { Marshal.ReleaseComObject(store); }
                    SHChangeNotify(0x2000, 0x0005, args[1], null);
                    return 0;
                }
                if (args.Length == 2 && args[0] == "--verify")
                {
                    var report = new StringBuilder();
                    foreach (IntPtr window in FindWindows())
                    {
                        IPropertyStore store = WindowStore(window);
                        try
                        {
                            report.AppendLine("Window=" + window + "; AppID=" + ReadString(store, 5) + "; Relaunch=" + ReadString(store, 2));
                            if (ReadString(store, 5) != AppId) throw new InvalidOperationException("Window identity does not match the launcher.");
                            IntPtr icon;
                            if (SendMessageTimeout(window, 0x7f, new IntPtr(1), IntPtr.Zero, 2, 1000, out icon) == IntPtr.Zero || icon == IntPtr.Zero) throw new InvalidOperationException("Window icon is missing.");
                        }
                        finally { Marshal.ReleaseComObject(store); }
                    }
                    if (report.Length == 0) throw new InvalidOperationException("No WSL Terminal window was found.");
                    File.WriteAllText(args[1], report.ToString());
                    return 0;
                }
                bool first;
                using (var mutex = new Mutex(true, "Local\\WSLTerminal.Identity", out first))
                {
                    try
                    {
                        if (!(args.Length == 1 && args[0] == "--adopt")) Process.Start(new ProcessStartInfo {
                            FileName = Path.Combine(Local, "Microsoft", "WindowsApps", "wt.exe"),
                            Arguments = "-w \"WSL Terminal\" new-tab -p \"WSL Terminal\"",
                            WorkingDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                            UseShellExecute = true
                        });
                        if (!first) return 0;
                        RunIdentityWorker();
                    }
                    finally { if (first) mutex.ReleaseMutex(); }
                }
                return 0;
            }
            catch (Exception error)
            {
                Log(error.ToString());
                if (args.Length == 0) MessageBox.Show(error.Message, "WSL Terminal", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }

        static void RunIdentityWorker()
        {
            var known = new HashSet<IntPtr>();
            var timer = Stopwatch.StartNew();
            using (var small = LoadIcon(32))
            using (var large = LoadIcon(48))
            {
                while (true)
                {
                    foreach (IntPtr window in FindWindows())
                    {
                        if (known.Contains(window)) continue;
                        IPropertyStore store = WindowStore(window);
                        try
                        {
                            SetIdentity(store);
                            if (ReadString(store, 5) != AppId) throw new InvalidOperationException("Windows rejected the WSL Terminal app identity.");
                            known.Add(window);
                            Log("Assigned WSL Terminal identity to window " + window);
                        }
                        finally { Marshal.ReleaseComObject(store); }
                    }
                    known.RemoveWhere(delegate(IntPtr window) { return !IsWindow(window); });
                    foreach (IntPtr window in known)
                    {
                        SetIcon(window, 0, small.Handle);
                        SetIcon(window, 1, large.Handle);
                    }
                    if (known.Count == 0 && timer.Elapsed.TotalSeconds > 20) break;
                    Thread.Sleep(500);
                }
            }
        }

        static Icon LoadIcon(int size)
        {
            using (Stream stream = typeof(Program).Assembly.GetManifestResourceStream("WSLTerminal.Icon"))
            {
                if (stream == null) throw new InvalidOperationException("The embedded Terminal icon resource is missing.");
                using (var icon = new Icon(stream, size, size)) return (Icon)icon.Clone();
            }
        }

        static void SetIcon(IntPtr window, int size, IntPtr icon)
        {
            IntPtr result;
            SendMessageTimeout(window, 0x80, new IntPtr(size), icon, 2, 1000, out result);
        }

        static List<IntPtr> FindWindows()
        {
            var result = new List<IntPtr>();
            EnumWindows(delegate(IntPtr window, IntPtr unused) {
                if (!IsWindowVisible(window)) return true;
                var title = new StringBuilder(1024);
                GetWindowText(window, title, title.Capacity);
                if (title.ToString().IndexOf("WSL Terminal", StringComparison.Ordinal) < 0) return true;
                uint pid;
                GetWindowThreadProcessId(window, out pid);
                try
                {
                    using (var process = Process.GetProcessById((int)pid))
                        if (process.ProcessName.Equals("WindowsTerminal", StringComparison.OrdinalIgnoreCase)) result.Add(window);
                }
                catch (ArgumentException) { }
                return true;
            }, IntPtr.Zero);
            return result;
        }

        static IPropertyStore WindowStore(IntPtr window)
        {
            IPropertyStore store;
            Guid iid = StoreGuid;
            Marshal.ThrowExceptionForHR(SHGetPropertyStoreForWindow(window, ref iid, out store));
            return store;
        }
        static void SetIdentity(IPropertyStore store)
        {
            SetString(store, 2, "\"" + Executable + "\"");
            SetString(store, 3, Executable + ",0");
            SetString(store, 4, "WSL Terminal");
            SetString(store, 5, AppId);
        }
        static void SetString(IPropertyStore store, uint id, string text)
        {
            var key = new PropertyKey { Format = PropertyGuid, Id = id };
            var value = new PropVariant { Type = 31, Pointer = Marshal.StringToCoTaskMemUni(text) };
            try { Marshal.ThrowExceptionForHR(store.SetValue(ref key, ref value)); }
            finally { Marshal.FreeCoTaskMem(value.Pointer); }
        }
        static string ReadString(IPropertyStore store, uint id)
        {
            var key = new PropertyKey { Format = PropertyGuid, Id = id };
            PropVariant value;
            Marshal.ThrowExceptionForHR(store.GetValue(ref key, out value));
            try { return value.Type == 31 ? Marshal.PtrToStringUni(value.Pointer) : ""; }
            finally { PropVariantClear(ref value); }
        }
        static void Log(string text) { File.AppendAllText(LogPath, DateTime.Now.ToString("s") + " " + text + Environment.NewLine); }

        delegate bool EnumWindowsCallback(IntPtr window, IntPtr parameter);
        [StructLayout(LayoutKind.Sequential)] struct PropertyKey { public Guid Format; public uint Id; }
        [StructLayout(LayoutKind.Explicit, Size = 24)] struct PropVariant {
            [FieldOffset(0)] public ushort Type;
            [FieldOffset(8)] public IntPtr Pointer;
        }
        [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IPropertyStore {
            [PreserveSig] int GetCount(out uint count);
            [PreserveSig] int GetAt(uint index, out PropertyKey key);
            [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
            [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant value);
            [PreserveSig] int Commit();
        }
        [DllImport("shell32.dll")] static extern int SHGetPropertyStoreForWindow(IntPtr window, ref Guid iid, out IPropertyStore store);
        [DllImport("shell32.dll", CharSet=CharSet.Unicode)] static extern void SHChangeNotify(uint eventId, uint flags, string item1, string item2);
        [DllImport("shell32.dll", CharSet=CharSet.Unicode)] static extern int SHGetPropertyStoreFromParsingName(string path, IntPtr context, uint flags, ref Guid iid, out IPropertyStore store);
        [DllImport("ole32.dll")] static extern int PropVariantClear(ref PropVariant value);
        [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsCallback callback, IntPtr parameter);
        [DllImport("user32.dll")] static extern bool IsWindow(IntPtr window);
        [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window, StringBuilder title, int max);
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
        [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wparam, IntPtr lparam, uint flags, uint timeout, out IntPtr result);
    }
}
