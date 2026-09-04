using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

namespace TeamsQuickChat;

internal static class ShellShortcut
{
    private static readonly PropertyKey AppUserModelIdKey = new(
        new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
        5);
    private static readonly Guid ShellItemInterfaceId = new(
        "43826D1E-E718-42EE-BC55-A1E261C37BFE");

    internal static void Create(
        string shortcutPath,
        string targetPath,
        string arguments,
        string description,
        string appUserModelId)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(shortcutPath)!);

        var link = (IShellLinkW)(object)new ShellLink();
        try
        {
            ThrowIfFailed(link.SetPath(targetPath));
            ThrowIfFailed(link.SetArguments(arguments));
            ThrowIfFailed(link.SetWorkingDirectory(Path.GetDirectoryName(targetPath)!));
            ThrowIfFailed(link.SetDescription(description));
            ThrowIfFailed(link.SetIconLocation(targetPath, 0));

            var propertyStore = (IPropertyStore)link;
            var appId = default(PropVariant);
            try
            {
                appId = PropVariant.FromString(appUserModelId);
                var key = AppUserModelIdKey;
                ThrowIfFailed(propertyStore.SetValue(ref key, ref appId));
                ThrowIfFailed(propertyStore.Commit());
            }
            finally
            {
                appId.Dispose();
            }

            ((IPersistFile)link).Save(shortcutPath, true);
        }
        finally
        {
            Marshal.FinalReleaseComObject(link);
        }

        SHChangeNotify(
            ShellChangeEventCreate,
            ShellChangeNotifyPathW,
            shortcutPath,
            IntPtr.Zero);
    }

    internal static void Unpin(string shortcutPath)
    {
        var interfaceId = ShellItemInterfaceId;
        ThrowIfFailed(SHCreateItemFromParsingName(
            shortcutPath,
            IntPtr.Zero,
            ref interfaceId,
            out var shellItem));

        IStartMenuPinnedList? pinnedList = null;
        try
        {
            pinnedList = (IStartMenuPinnedList)(object)new StartMenuPin();
            ThrowIfFailed(pinnedList.RemoveFromList(shellItem));
        }
        finally
        {
            Marshal.Release(shellItem);
            if (pinnedList is not null)
                Marshal.FinalReleaseComObject(pinnedList);
        }
    }

    private static void ThrowIfFailed(int hresult)
    {
        if (hresult < 0)
            Marshal.ThrowExceptionForHR(hresult);
    }

    private const uint ShellChangeEventCreate = 0x00000002;
    private const uint ShellChangeNotifyPathW = 0x0005;

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern void SHChangeNotify(
        uint eventId,
        uint flags,
        string item1,
        IntPtr item2);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHCreateItemFromParsingName(
        string path,
        IntPtr bindContext,
        ref Guid interfaceId,
        out IntPtr shellItem);

    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    private sealed class ShellLink;

    [ComImport]
    [Guid("A2A9545D-A0C2-42B4-9708-A0B2BADD77C8")]
    private sealed class StartMenuPin;

    [ComImport]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IShellLinkW
    {
        [PreserveSig]
        int GetPath(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder file,
            int fileLength,
            IntPtr findData,
            uint flags);

        [PreserveSig]
        int GetIDList(out IntPtr itemIdList);

        [PreserveSig]
        int SetIDList(IntPtr itemIdList);

        [PreserveSig]
        int GetDescription(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder description,
            int descriptionLength);

        [PreserveSig]
        int SetDescription([MarshalAs(UnmanagedType.LPWStr)] string description);

        [PreserveSig]
        int GetWorkingDirectory(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder workingDirectory,
            int workingDirectoryLength);

        [PreserveSig]
        int SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string workingDirectory);

        [PreserveSig]
        int GetArguments(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder arguments,
            int argumentsLength);

        [PreserveSig]
        int SetArguments([MarshalAs(UnmanagedType.LPWStr)] string arguments);

        [PreserveSig]
        int GetHotkey(out short hotkey);

        [PreserveSig]
        int SetHotkey(short hotkey);

        [PreserveSig]
        int GetShowCmd(out int showCommand);

        [PreserveSig]
        int SetShowCmd(int showCommand);

        [PreserveSig]
        int GetIconLocation(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder iconPath,
            int iconPathLength,
            out int iconIndex);

        [PreserveSig]
        int SetIconLocation(
            [MarshalAs(UnmanagedType.LPWStr)] string iconPath,
            int iconIndex);

        [PreserveSig]
        int SetRelativePath(
            [MarshalAs(UnmanagedType.LPWStr)] string path,
            uint reserved);

        [PreserveSig]
        int Resolve(IntPtr windowHandle, uint flags);

        [PreserveSig]
        int SetPath([MarshalAs(UnmanagedType.LPWStr)] string path);
    }

    [ComImport]
    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPropertyStore
    {
        [PreserveSig]
        int GetCount(out uint propertyCount);

        [PreserveSig]
        int GetAt(uint propertyIndex, out PropertyKey key);

        [PreserveSig]
        int GetValue(ref PropertyKey key, out PropVariant value);

        [PreserveSig]
        int SetValue(ref PropertyKey key, ref PropVariant value);

        [PreserveSig]
        int Commit();
    }

    [ComImport]
    [Guid("4CD19ADA-25A5-4A32-B3B7-347BEE5BE36B")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IStartMenuPinnedList
    {
        [PreserveSig]
        int RemoveFromList(IntPtr shellItem);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    private readonly struct PropertyKey(Guid formatId, uint propertyId)
    {
        internal readonly Guid FormatId = formatId;
        internal readonly uint PropertyId = propertyId;
    }

    [StructLayout(LayoutKind.Explicit, Size = 24)]
    private struct PropVariant
    {
        [FieldOffset(0)]
        internal ushort VariantType;

        [FieldOffset(8)]
        private IntPtr PointerValue;

        internal static PropVariant FromString(string value) => new()
        {
            VariantType = 31,
            PointerValue = Marshal.StringToCoTaskMemUni(value)
        };

        internal void Dispose()
        {
            Marshal.FreeCoTaskMem(PointerValue);
            this = default;
        }
    }
}
