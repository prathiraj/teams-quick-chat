namespace TeamsQuickChat;

public class AddContactDialog : Form
{
    private TextBox nameBox = null!;
    private TextBox emailBox = null!;

    public AddContactDialog()
    {
        Text = "Add Contact";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(320, 150);
        BuildUI();
    }

    private void BuildUI()
    {
        var nameLabel = new Label { Text = "Name:", Location = new Point(12, 15), AutoSize = true };
        nameBox = new TextBox { Location = new Point(70, 12), Width = 230 };

        var emailLabel = new Label { Text = "Email:", Location = new Point(12, 50), AutoSize = true };
        emailBox = new TextBox { Location = new Point(70, 47), Width = 230 };

        var saveBtn = new Button { Text = "Save", Location = new Point(140, 100), Width = 75, DialogResult = DialogResult.OK };
        var cancelBtn = new Button { Text = "Cancel", Location = new Point(225, 100), Width = 75, DialogResult = DialogResult.Cancel };

        saveBtn.Click += (_, _) =>
        {
            var email = emailBox.Text.Trim();
            if (string.IsNullOrEmpty(email))
            {
                MessageBox.Show("Email is required.", "Validation", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                DialogResult = DialogResult.None;
                return;
            }
            var name = nameBox.Text.Trim();
            if (string.IsNullOrEmpty(name))
                name = email.Split('@')[0];

            ContactStore.Add(name, email);
        };

        AcceptButton = saveBtn;
        CancelButton = cancelBtn;
        Controls.AddRange([nameLabel, nameBox, emailLabel, emailBox, saveBtn, cancelBtn]);
    }
}
