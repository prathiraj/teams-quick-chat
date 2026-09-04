namespace TeamsQuickChat;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        var logPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "TeamsQuickChat", "crash.log");

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(logPath)!);
            var launchRequest = TaskbarPinning.ParseLaunchRequest(args);
            AppIdentity.SetCurrentProcess(
                launchRequest?.AppUserModelId ?? AppIdentity.DefaultAppUserModelId);

            ApplicationConfiguration.Initialize();

            switch (launchRequest)
            {
                case OpenPinnedChatRequest openChat:
                    TeamsDeepLink.OpenPinnedChat(openChat.ChatUri);
                    break;
                case TaskbarPinRequest pinRequest:
                    Application.Run(new TaskbarPinRequestForm(pinRequest));
                    break;
                case RemoveTaskbarPinsRequest:
                    TaskbarPinning.RemoveAllShortcuts();
                    break;
                default:
                    Application.Run(new Form1());
                    break;
            }
        }
        catch (Exception ex)
        {
            File.WriteAllText(logPath, $"{DateTime.Now}\n{ex}");
            MessageBox.Show(
                $"TeamsQuickChat crashed:\n\n{ex.Message}\n\nLog saved to:\n{logPath}",
                "TeamsQuickChat Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}