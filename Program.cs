namespace TeamsQuickChat;

static class Program
{
    [STAThread]
    static void Main()
    {
        var logPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "TeamsQuickChat", "crash.log");

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(logPath)!);
            ApplicationConfiguration.Initialize();
            Application.Run(new Form1());
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