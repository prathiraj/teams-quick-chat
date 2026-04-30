using System.Runtime.InteropServices;

namespace TeamsQuickChat;

public partial class Form1 : Form
{
    private FlowLayoutPanel contactPanel = null!;
    private NotifyIcon trayIcon = null!;

    // Drag-and-drop reordering state
    private Panel? _dragRow;
    private Point _dragStartPos;
    private bool _isDragging;
    private const int DRAG_THRESHOLD = 5;

    // Win11 rounded corners
    [DllImport("dwmapi.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    private static extern void DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int pvAttribute, int cbAttribute);
    private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    private const int DWMWCP_ROUND = 2;
    private const int DWMWCP_ROUNDSMALL = 3;

    // WS_EX_TOOLWINDOW hides from Alt-Tab
    private const int WS_EX_TOOLWINDOW = 0x00000080;

    public Form1()
    {
        InitializeComponent();
        Text = "Teams Quick Chat";
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        BackColor = Color.White;
        Padding = new Padding(1);
        ClientSize = new Size(320, 400);

        SetupTrayIcon();
        BuildUI();
        RefreshContacts();

        // Start hidden — user clicks tray icon to show
        Visible = false;

        // Auto-check for updates on startup (fire-and-forget, silent on failure)
        _ = UpdateChecker.PromptAndUpdateAsync(showUpToDate: false);
    }

    private void SetupTrayIcon()
    {
        trayIcon = new NotifyIcon
        {
            Text = "Teams Quick Chat",
            Visible = true
        };

        // Load icon from exe or fall back to a default
        var iconPath = Path.Combine(AppContext.BaseDirectory, "icon.ico");
        if (File.Exists(iconPath))
            trayIcon.Icon = new Icon(iconPath);
        else if (Icon != null)
            trayIcon.Icon = Icon;
        else
            trayIcon.Icon = SystemIcons.Application;

        trayIcon.MouseClick += (_, e) =>
        {
            if (e.Button == MouseButtons.Left)
                ToggleFlyout();
        };

        // Right-click context menu for exit
        var menu = new ContextMenuStrip();
        menu.Items.Add("Check for updates", null, async (_, _) => await UpdateChecker.PromptAndUpdateAsync(showUpToDate: true));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Exit", null, (_, _) => { trayIcon.Visible = false; Application.Exit(); });
        trayIcon.ContextMenuStrip = menu;
    }

    private void ToggleFlyout()
    {
        if (Visible)
        {
            Hide();
        }
        else
        {
            ResizeToFitContacts();
            RefreshContacts();
            PositionAboveTaskbar();
            Show();
            Activate();
        }
    }

    private const int ROW_HEIGHT = 44;
    private const int ROW_MARGIN = 6;     // WinForms default top+bottom margin per control
    private const int HEADER_HEIGHT = 45; // header + separator
    private const int MIN_HEIGHT = 120;
    private const int MAX_CONTACTS_VISIBLE = 15;

    private void ResizeToFitContacts()
    {
        var count = ContactStore.Load().Count;
        // Account for: header, panel padding (12), form padding (2), row margins
        int contentHeight = count > 0
            ? HEADER_HEIGHT + 14 + ((ROW_HEIGHT + ROW_MARGIN) * Math.Min(count, MAX_CONTACTS_VISIBLE)) + 4
            : MIN_HEIGHT;

        var workArea = Screen.FromPoint(Cursor.Position).WorkingArea;
        int maxHeight = workArea.Height - 40;
        ClientSize = new Size(ClientSize.Width, Math.Min(Math.Max(contentHeight, MIN_HEIGHT), maxHeight));
    }
    protected override CreateParams CreateParams
    {
        get
        {
            var cp = base.CreateParams;
            cp.ClassStyle |= 0x00020000; // CS_DROPSHADOW
            cp.ExStyle |= WS_EX_TOOLWINDOW;
            return cp;
        }
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        try
        {
            int preference = DWMWCP_ROUND;
            DwmSetWindowAttribute(Handle, DWMWA_WINDOW_CORNER_PREFERENCE, ref preference, sizeof(int));

            // Add a subtle border via DWM (DWMWA_BORDER_COLOR = 34)
            int borderColor = ColorTranslator.ToWin32(Color.FromArgb(229, 231, 235));
            DwmSetWindowAttribute(Handle, 34, ref borderColor, sizeof(int));
        }
        catch { /* Pre-Win11, ignore */ }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        // No manual border — DWM handles rounded border on Win11
        base.OnPaint(e);
    }

    protected override void OnDeactivate(EventArgs e)
    {
        base.OnDeactivate(e);
        // Auto-hide when clicking outside (like a flyout)
        Hide();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        // Minimize to tray on close button (if ever shown)
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            Hide();
            return;
        }
        trayIcon.Visible = false;
        base.OnFormClosing(e);
    }

    private void PositionAboveTaskbar()
    {
        var screen = Screen.FromPoint(Cursor.Position);
        var work = screen.WorkingArea;
        var bounds = screen.Bounds;
        var cursor = Cursor.Position;

        // Center horizontally on the cursor (taskbar icon location), clamp to screen
        int x = cursor.X - Width / 2;
        x = Math.Max(work.Left + 4, Math.Min(x, work.Right - Width - 4));

        int y;
        if (work.Bottom < bounds.Bottom)
            y = work.Bottom - Height - 8;       // Taskbar at bottom
        else if (work.Top > bounds.Top)
            y = work.Top + 8;                    // Taskbar at top
        else if (work.Right < bounds.Right)
            y = cursor.Y - Height / 2;           // Taskbar at right
        else
            y = cursor.Y - Height / 2;           // Taskbar at left

        y = Math.Max(work.Top + 4, Math.Min(y, work.Bottom - Height - 4));

        Location = new Point(x, y);
    }

    private void BuildUI()
    {
        // Header
        var header = new Panel
        {
            Dock = DockStyle.Top,
            Height = 48,
            BackColor = Color.White
        };

        var title = new Label
        {
            Text = "Teams Quick Chat",
            Font = new Font("Segoe UI", 10, FontStyle.Bold),
            ForeColor = Color.FromArgb(30, 30, 30),
            Location = new Point(16, 14),
            AutoSize = true
        };

        var addBtn = new Button
        {
            Text = "+",
            Font = new Font("Segoe UI", 14),
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(238, 238, 238),
            ForeColor = Color.FromArgb(50, 50, 50),
            Size = new Size(28, 28),
            Cursor = Cursors.Hand,
            TextAlign = ContentAlignment.MiddleCenter,
            Padding = Padding.Empty,
            Margin = Padding.Empty,
            UseCompatibleTextRendering = true,
            Anchor = AnchorStyles.Top | AnchorStyles.Right
        };
        addBtn.Location = new Point(header.ClientSize.Width - addBtn.Width - 16, 10);
        addBtn.FlatAppearance.BorderSize = 0;
        addBtn.Click += (_, _) =>
        {
            using var dlg = new AddContactDialog();
            if (dlg.ShowDialog(this) == DialogResult.OK)
                RefreshContacts();
        };

        header.Controls.AddRange([title, addBtn]);
        Controls.Add(header);

        // Separator
        var sep = new Panel
        {
            Dock = DockStyle.Top,
            Height = 1,
            BackColor = Color.FromArgb(229, 231, 235)
        };
        Controls.Add(sep);
        sep.BringToFront();

        // Scrollable contact list
        contactPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoScroll = true,
            FlowDirection = FlowDirection.TopDown,
            WrapContents = false,
            BackColor = Color.White,
            Padding = new Padding(0, 4, 0, 4)
        };
        // Suppress horizontal scrollbar
        contactPanel.HorizontalScroll.Maximum = 0;
        contactPanel.AutoScrollMargin = new Size(0, 0);
        contactPanel.HorizontalScroll.Visible = false;
        Controls.Add(contactPanel);
        contactPanel.BringToFront();
    }

    private void RefreshContacts()
    {
        contactPanel.SuspendLayout();
        contactPanel.Controls.Clear();

        var contacts = ContactStore.Load();

        if (contacts.Count == 0)
        {
            var empty = new Label
            {
                Text = "No contacts yet.\nClick + to get started.",
                Font = new Font("Segoe UI", 10),
                ForeColor = Color.Gray,
                TextAlign = ContentAlignment.MiddleCenter,
                AutoSize = false,
                Size = new Size(270, 80),
                Padding = new Padding(0, 30, 0, 0)
            };
            contactPanel.Controls.Add(empty);
        }
        else
        {
            foreach (var contact in contacts)
            {
                var row = CreateContactRow(contact);
                contactPanel.Controls.Add(row);
            }
        }

        contactPanel.ResumeLayout();
    }

    private static readonly Color PrimaryLight = Color.FromArgb(237, 237, 255);
    private static readonly Color Primary = Color.FromArgb(90, 90, 230);
    private static readonly Color RowBg = Color.White;
    private static readonly Color RowHover = Color.FromArgb(240, 240, 245);
    private static readonly Color SepColor = Color.FromArgb(243, 243, 243);

    private static string GetInitials(string name)
    {
        var parts = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 2)
            return $"{parts[0][0]}{parts[^1][0]}".ToUpper();
        return name.Length >= 2 ? name[..2].ToUpper() : name.ToUpper();
    }

    private Panel CreateContactRow(Contact contact)
    {
        int rowWidth = contactPanel.ClientSize.Width - contactPanel.Padding.Horizontal;
        var row = new Panel
        {
            Width = rowWidth,
            Height = ROW_HEIGHT,
            BackColor = RowBg,
            Cursor = Cursors.Hand,
            Tag = contact
        };

        // Bottom separator line
        var sep = new Panel
        {
            Height = 1,
            Dock = DockStyle.Bottom,
            BackColor = SepColor
        };
        row.Controls.Add(sep);

        // Avatar circle with initials
        var avatar = new Label
        {
            Text = GetInitials(contact.Name),
            Font = new Font("Segoe UI", 8, FontStyle.Bold),
            ForeColor = Primary,
            BackColor = PrimaryLight,
            Size = new Size(32, 32),
            Location = new Point(16, 6),
            TextAlign = ContentAlignment.MiddleCenter,
            Cursor = Cursors.Hand
        };
        // Make it circular via Region
        var gp = new System.Drawing.Drawing2D.GraphicsPath();
        gp.AddEllipse(0, 0, 32, 32);
        avatar.Region = new Region(gp);
        row.Controls.Add(avatar);

        // Name
        var nameLabel = new Label
        {
            Text = contact.Name,
            Font = new Font("Segoe UI", 9.5f, FontStyle.Regular),
            ForeColor = Color.FromArgb(30, 30, 30),
            Location = new Point(58, 12),
            AutoSize = true,
            Cursor = Cursors.Hand
        };
        row.Controls.Add(nameLabel);

        // Drag grip dots (right side)
        var grip = new Label
        {
            Text = "⠿",
            Font = new Font("Segoe UI", 10),
            ForeColor = Color.FromArgb(200, 200, 200),
            Location = new Point(rowWidth - 28, 12),
            AutoSize = true,
            Cursor = Cursors.SizeAll,
            Anchor = AnchorStyles.Top | AnchorStyles.Right
        };
        row.Controls.Add(grip);

        var email = contact.Email;

        // Right-click context menu for remove
        var ctxMenu = new ContextMenuStrip();
        ctxMenu.Items.Add("Remove", null, (_, _) =>
        {
            ContactStore.Remove(email);
            RefreshContacts();
        });
        row.ContextMenuStrip = ctxMenu;
        nameLabel.ContextMenuStrip = ctxMenu;
        avatar.ContextMenuStrip = ctxMenu;

        // Hover highlight
        void SetHover(Control c, bool enter)
        {
            if (!_isDragging)
                row.BackColor = enter ? RowHover : RowBg;
        }
        foreach (Control c in new Control[] { row, nameLabel, avatar, grip })
        {
            c.MouseEnter += (_, _) => SetHover(c, true);
            c.MouseLeave += (_, _) => SetHover(c, false);
        }

        // Click opens chat
        row.Click += (_, _) => { if (!_isDragging) TeamsDeepLink.OpenChat(email); };
        nameLabel.Click += (_, _) => { if (!_isDragging) TeamsDeepLink.OpenChat(email); };
        avatar.Click += (_, _) => { if (!_isDragging) TeamsDeepLink.OpenChat(email); };

        // Drag-and-drop reordering
        void OnMouseDown(object? s, MouseEventArgs e) { if (e.Button == MouseButtons.Left) DragStart(row, e); }
        void OnMouseMove(object? s, MouseEventArgs e) { DragMove(row, e); }
        void OnMouseUp(object? s, MouseEventArgs e) { DragEnd(); }

        foreach (Control c in new Control[] { row, nameLabel, avatar, grip })
        {
            c.MouseDown += OnMouseDown;
            c.MouseMove += OnMouseMove;
            c.MouseUp += OnMouseUp;
        }

        return row;
    }

    private void DragStart(Panel row, MouseEventArgs e)
    {
        _dragRow = row;
        _dragStartPos = Cursor.Position;
        _isDragging = false;
    }

    private void DragMove(Panel row, MouseEventArgs e)
    {
        if (_dragRow == null) return;

        if (!_isDragging)
        {
            var delta = Math.Abs(Cursor.Position.Y - _dragStartPos.Y);
            if (delta < DRAG_THRESHOLD) return;
            _isDragging = true;
            _dragRow.BackColor = Color.FromArgb(237, 237, 255);
            _dragRow.Cursor = Cursors.SizeAll;
        }

        // Find which row the cursor is over and swap
        var pt = contactPanel.PointToClient(Cursor.Position);
        foreach (Control ctrl in contactPanel.Controls)
        {
            if (ctrl == _dragRow || ctrl is not Panel target) continue;
            if (target.Bounds.Contains(pt))
            {
                int dragIdx = contactPanel.Controls.GetChildIndex(_dragRow);
                int targetIdx = contactPanel.Controls.GetChildIndex(target);
                if (dragIdx != targetIdx)
                {
                    contactPanel.Controls.SetChildIndex(_dragRow, targetIdx);
                }
                break;
            }
        }
    }

    private void DragEnd()
    {
        if (_dragRow != null)
        {
            _dragRow.BackColor = RowBg;
            _dragRow.Cursor = Cursors.Hand;
        }

        if (_isDragging)
        {
            // Persist the new order
            var reordered = new List<Contact>();
            foreach (Control ctrl in contactPanel.Controls)
            {
                if (ctrl is Panel row && row.Tag is Contact c)
                    reordered.Add(c);
            }
            if (reordered.Count > 0)
                ContactStore.Save(reordered);
        }

        _dragRow = null;
        _isDragging = false;
    }
}
