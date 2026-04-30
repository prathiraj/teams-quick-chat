namespace TeamsQuickChat;

/// <summary>
/// FlowLayoutPanel that completely suppresses horizontal scrolling.
/// </summary>
public class NoHScrollFlowPanel : FlowLayoutPanel
{
    private const int WS_HSCROLL = 0x00100000;
    private const int WM_NCCALCSIZE = 0x0083;
    private const int GWL_STYLE = -16;

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_NCCALCSIZE)
        {
            int style = GetWindowLong(Handle, GWL_STYLE);
            if ((style & WS_HSCROLL) != 0)
                SetWindowLong(Handle, GWL_STYLE, style & ~WS_HSCROLL);
        }
        base.WndProc(ref m);

        // Always reset horizontal scroll position to 0
        if (HorizontalScroll.Value != 0)
        {
            HorizontalScroll.Value = 0;
            PerformLayout();
        }
    }

    protected override void OnScroll(ScrollEventArgs se)
    {
        if (se.ScrollOrientation == ScrollOrientation.HorizontalScroll)
        {
            se = new ScrollEventArgs(se.Type, 0, 0, ScrollOrientation.HorizontalScroll);
        }
        base.OnScroll(se);
    }
}
