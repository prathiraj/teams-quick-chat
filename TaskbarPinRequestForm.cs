using System.Runtime.InteropServices;
using Windows.UI.Shell;

namespace TeamsQuickChat;

internal sealed class TaskbarPinRequestForm : Form
{
    private const int AccessDenied = unchecked((int)0x80070005);
    private const int ClassNotRegistered = unchecked((int)0x80040154);
    private const int NotImplemented = unchecked((int)0x80004001);

    private readonly TaskbarPinRequest _request;
    private readonly Label _statusLabel;

    internal TaskbarPinRequestForm(TaskbarPinRequest request)
    {
        _request = request;

        Text = $"Pin {request.DisplayName}";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(380, 112);
        MaximizeBox = false;
        MinimizeBox = false;
        ShowInTaskbar = false;
        ControlBox = false;

        _statusLabel = new Label
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(24),
            TextAlign = ContentAlignment.MiddleCenter,
            Text = $"Preparing the {request.DisplayName} taskbar shortcut..."
        };
        Controls.Add(_statusLabel);

        Shown += async (_, _) => await RequestPinAsync();
    }

    private async Task RequestPinAsync()
    {
        Activate();
        await Task.Delay(200);

        try
        {
            var taskbarManager = TaskbarManager.GetDefault();
            if (taskbarManager is null || !taskbarManager.IsPinningAllowed)
            {
                ShowManualPinInstructions(
                    "Windows or your organization currently prevents apps from requesting a taskbar pin.");
                return;
            }

            _statusLabel.Text = $"Confirm the Windows prompt to pin {_request.DisplayName}.";
            await Task.Delay(100);
            await taskbarManager.RequestPinCurrentAppAsync();
            Close();
        }
        catch (Exception ex) when (
            ex is UnauthorizedAccessException or NotSupportedException or TypeLoadException ||
            ex is COMException
            {
                HResult: AccessDenied or ClassNotRegistered or NotImplemented
            })
        {
            ShowManualPinInstructions(
                "Automatic taskbar pinning is unavailable on this Windows installation.");
        }
    }

    private void ShowManualPinInstructions(string reason)
    {
        MessageBox.Show(
            this,
            $"{reason}\n\n" +
            "The chat shortcut was created in your Start menu. " +
            "Right-click it and choose \"Pin to taskbar\".",
            "Pin to taskbar",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);

        try
        {
            TaskbarPinning.RevealShortcut(_request.ShortcutPath);
        }
        catch (TaskbarPinningException ex)
        {
            MessageBox.Show(
                this,
                ex.Message,
                "Teams Quick Chat",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
        }

        Close();
    }
}
