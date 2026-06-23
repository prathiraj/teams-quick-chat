namespace TeamsQuickChat;

public class AddContactDialog : Form
{
    private TextBox nameBox = null!;
    private TextBox emailBox = null!;
    private TextBox linkBox = null!;
    private RadioButton emailRadio = null!;
    private RadioButton linkRadio = null!;
    private Label emailLabel = null!;
    private Label linkLabel = null!;
    private Label helpLabel = null!;

    public AddContactDialog()
    {
        Text = "Add Contact";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(440, 225);
        BuildUI();
    }

    private void BuildUI()
    {
        var nameLabel = new Label { Text = "Name:", Location = new Point(12, 15), AutoSize = true };
        nameBox = new TextBox { Location = new Point(105, 12), Width = 310 };

        var addByLabel = new Label { Text = "Add by:", Location = new Point(12, 50), AutoSize = true };
        emailRadio = new RadioButton { Text = "Email address", Location = new Point(105, 48), AutoSize = true, Checked = true };
        linkRadio = new RadioButton { Text = "Teams chat link", Location = new Point(225, 48), AutoSize = true };

        emailLabel = new Label { Text = "Email:", Location = new Point(12, 85), AutoSize = true };
        emailBox = new TextBox { Location = new Point(105, 82), Width = 310 };

        linkLabel = new Label { Text = "Teams link:", Location = new Point(12, 85), AutoSize = true, Visible = false };
        linkBox = new TextBox { Location = new Point(105, 82), Width = 310, Visible = false };

        helpLabel = new Label
        {
            Location = new Point(105, 112),
            Size = new Size(310, 45),
            ForeColor = Color.DimGray
        };

        var saveBtn = new Button { Text = "Save", Location = new Point(260, 180), Width = 75, DialogResult = DialogResult.OK };
        var cancelBtn = new Button { Text = "Cancel", Location = new Point(345, 180), Width = 75, DialogResult = DialogResult.Cancel };

        emailRadio.CheckedChanged += (_, _) => UpdateModeUI();
        linkRadio.CheckedChanged += (_, _) => UpdateModeUI();

        saveBtn.Click += (_, _) =>
        {
            if (!SaveContact())
                DialogResult = DialogResult.None;
        };

        AcceptButton = saveBtn;
        CancelButton = cancelBtn;
        Controls.AddRange([
            nameLabel, nameBox,
            addByLabel, emailRadio, linkRadio,
            emailLabel, emailBox, linkLabel, linkBox, helpLabel,
            saveBtn, cancelBtn
        ]);
        UpdateModeUI();
    }

    private void UpdateModeUI()
    {
        var linkMode = linkRadio.Checked;

        emailLabel.Visible = !linkMode;
        emailBox.Visible = !linkMode;
        linkLabel.Visible = linkMode;
        linkBox.Visible = linkMode;

        helpLabel.Text = linkMode
            ? "Paste a Teams chat link copied from Teams. A display name is required."
            : "Enter a person's email address. Blank names default to the email prefix.";
    }

    private bool SaveContact()
    {
        return linkRadio.Checked ? SaveTeamsLinkShortcut() : SaveEmailContact();
    }

    private bool SaveEmailContact()
    {
        var email = emailBox.Text.Trim();
        if (string.IsNullOrEmpty(email))
        {
            ShowValidation("Email is required.");
            return false;
        }

        var name = nameBox.Text.Trim();
        if (string.IsNullOrEmpty(name))
            name = email.Split('@')[0];

        ContactStore.AddEmail(name, email);
        return true;
    }

    private bool SaveTeamsLinkShortcut()
    {
        var name = nameBox.Text.Trim();
        if (string.IsNullOrEmpty(name))
        {
            ShowValidation("Name is required for Teams chat links.");
            return false;
        }

        var link = linkBox.Text.Trim();
        if (string.IsNullOrEmpty(link))
        {
            ShowValidation("Teams chat link is required.");
            return false;
        }

        if (!TeamsDeepLink.TryNormalizeTeamsWebLink(link, out var teamsLink))
        {
            ShowValidation("Paste a Teams chat link copied from Teams.");
            return false;
        }

        ContactStore.AddTeamsLink(name, teamsLink);
        return true;
    }

    private static void ShowValidation(string message)
    {
        MessageBox.Show(message, "Validation", MessageBoxButtons.OK, MessageBoxIcon.Warning);
    }
}
