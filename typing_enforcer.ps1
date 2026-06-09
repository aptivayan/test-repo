#Requires -Version 5.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# WinForms参照なしでキーボードフック・ウィンドウ検索を実装
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class PracticeEnforcer {
    // Virtual Key Codes
    private const int VK_LWIN    = 0x5B;
    private const int VK_RWIN    = 0x5C;
    private const int VK_TAB     = 0x09;
    private const int VK_F4      = 0x73;
    private const int VK_ESCAPE  = 0x1B;
    private const int VK_MENU    = 0x12;  // Alt
    private const int VK_CONTROL = 0x11;

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN     = 0x0100;
    private const int WM_SYSKEYDOWN  = 0x0104;

    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, LowLevelKeyboardProc cb, IntPtr hMod, uint tid);
    [DllImport("user32.dll")] static extern bool   UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll")] static extern short  GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public  static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool   ShowWindow(IntPtr hWnd, int nCmd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int n);
    [DllImport("user32.dll")] static extern bool   IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool   EnumWindows(EnumWindowsProc proc, IntPtr lParam);

    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    public delegate bool   EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    static IntPtr _hookID = IntPtr.Zero;
    static LowLevelKeyboardProc _proc;

    public static void InstallHook() {
        _proc = HookCallback;
        using (var p = Process.GetCurrentProcess())
        using (var m = p.MainModule) {
            _hookID = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(m.ModuleName), 0);
        }
    }

    public static void UninstallHook() {
        if (_hookID != IntPtr.Zero) { UnhookWindowsHookEx(_hookID); _hookID = IntPtr.Zero; }
    }

    static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int  vk   = Marshal.ReadInt32(lParam);
            bool alt  = (GetAsyncKeyState(VK_MENU)    & 0x8000) != 0;
            bool ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
            if (vk == VK_LWIN || vk == VK_RWIN ||
                (vk == VK_TAB    && alt)  ||
                (vk == VK_F4     && alt)  ||
                (vk == VK_ESCAPE && ctrl)) {
                return (IntPtr)1;
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    public static string GetForegroundTitle() {
        var sb = new StringBuilder(512);
        GetWindowText(GetForegroundWindow(), sb, 512);
        return sb.ToString();
    }

    public static IntPtr FindPracticeWindow() {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hwnd, lp) => {
            if (IsWindowVisible(hwnd)) {
                var sb = new StringBuilder(512);
                GetWindowText(hwnd, sb, 512);
                if (sb.ToString().Contains("タイピング練習")) { found = hwnd; return false; }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static void BringPracticeToFront() {
        IntPtr hwnd = FindPracticeWindow();
        if (hwnd != IntPtr.Zero) { ShowWindow(hwnd, 9); SetForegroundWindow(hwnd); }
    }
}
"@

$URL          = "https://manabi-gakushu.benesse.ne.jp/gakushu/typing/homeposition.html"
$PRACTICE_SEC = 60
$script:secsLeft = $PRACTICE_SEC
$script:done     = $false

# 色定数
$COL_BG     = [System.Drawing.Color]::FromArgb(30,  30,  30)
$COL_DARK   = [System.Drawing.Color]::FromArgb(15,  15,  30)
$COL_ORANGE = [System.Drawing.Color]::FromArgb(240, 136, 62)
$COL_GREEN  = [System.Drawing.Color]::FromArgb(63,  185, 80)
$COL_RED    = [System.Drawing.Color]::FromArgb(248, 81,  73)
$COL_GRAY   = [System.Drawing.Color]::FromArgb(180, 180, 180)
$COL_WHITE  = [System.Drawing.Color]::White

# ブラウザを開く
Start-Process $URL
Start-Sleep -Milliseconds 2000

# キーボードフックをインストール
[PracticeEnforcer]::InstallHook()

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$sw     = [int]$screen.Width
$sh     = [int]$screen.Height

# ---- 小タイマーウィンドウ（右上） ----
$timerForm = New-Object System.Windows.Forms.Form
$timerForm.Text            = "タイピング練習"
$timerForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$timerForm.TopMost         = $true
$timerForm.BackColor       = $COL_BG
$timerForm.ShowInTaskbar   = $false
$timerForm.Size            = New-Object System.Drawing.Size(220, 90)
$tfX = $screen.Right - 230
$tfY = $screen.Top + 10
$timerForm.Location = New-Object System.Drawing.Point($tfX, $tfY)
$timerForm.Add_FormClosing({ param($s,$e); if (-not $script:done) { $e.Cancel = $true } })

$timerLabel = New-Object System.Windows.Forms.Label
$timerLabel.Text      = "1:00"
$timerLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 32, [System.Drawing.FontStyle]::Bold)
$timerLabel.ForeColor = $COL_ORANGE
$timerLabel.BackColor = $COL_BG
$timerLabel.Size      = New-Object System.Drawing.Size(135, 62)
$timerLabel.Location  = New-Object System.Drawing.Point(5, 8)
$timerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$timerForm.Controls.Add($timerLabel)

$miniMsg = New-Object System.Windows.Forms.Label
$miniMsg.Text      = "練習中..."
$miniMsg.Font      = New-Object System.Drawing.Font("Meiryo UI", 9)
$miniMsg.ForeColor = $COL_GREEN
$miniMsg.BackColor = $COL_BG
$miniMsg.Size      = New-Object System.Drawing.Size(74, 62)
$miniMsg.Location  = New-Object System.Drawing.Point(142, 8)
$miniMsg.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$timerForm.Controls.Add($miniMsg)

$progBar = New-Object System.Windows.Forms.ProgressBar
$progBar.Minimum  = 0
$progBar.Maximum  = $PRACTICE_SEC
$progBar.Value    = 0
$progBar.Style    = [System.Windows.Forms.ProgressBarStyle]::Continuous
$progBar.Size     = New-Object System.Drawing.Size(200, 8)
$progBar.Location = New-Object System.Drawing.Point(10, 76)
$timerForm.Controls.Add($progBar)

# ---- フルスクリーン封鎖オーバーレイ ----
$overlay = New-Object System.Windows.Forms.Form
$overlay.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$overlay.WindowState     = [System.Windows.Forms.FormWindowState]::Maximized
$overlay.TopMost         = $true
$overlay.BackColor       = $COL_DARK
$overlay.ShowInTaskbar   = $false
$overlay.Add_FormClosing({ param($s,$e); if (-not $script:done) { $e.Cancel = $true } })

$warnLabel = New-Object System.Windows.Forms.Label
$warnLabel.Text      = "タイピング練習をしてください"
$warnLabel.Font      = New-Object System.Drawing.Font("Meiryo UI", 30, [System.Drawing.FontStyle]::Bold)
$warnLabel.ForeColor = $COL_RED
$warnLabel.BackColor = $COL_DARK
$warnLabel.Size      = New-Object System.Drawing.Size($sw, 80)
$wlY = $sh / 2 - 110
$warnLabel.Location  = New-Object System.Drawing.Point(0, $wlY)
$warnLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$overlay.Controls.Add($warnLabel)

$subLabel = New-Object System.Windows.Forms.Label
$subLabel.Text      = "下のボタンを押して練習ページに戻ってください"
$subLabel.Font      = New-Object System.Drawing.Font("Meiryo UI", 14)
$subLabel.ForeColor = $COL_GRAY
$subLabel.BackColor = $COL_DARK
$subLabel.Size      = New-Object System.Drawing.Size($sw, 40)
$slY = $sh / 2 - 10
$subLabel.Location  = New-Object System.Drawing.Point(0, $slY)
$subLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$overlay.Controls.Add($subLabel)

$backBtn = New-Object System.Windows.Forms.Button
$backBtn.Text      = "練習に戻る"
$backBtn.Font      = New-Object System.Drawing.Font("Meiryo UI", 20, [System.Drawing.FontStyle]::Bold)
$backBtn.ForeColor = $COL_WHITE
$backBtn.BackColor = $COL_GREEN
$backBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$backBtn.Size      = New-Object System.Drawing.Size(280, 65)
$bbX = ($sw - 280) / 2
$bbY = $sh / 2 + 50
$backBtn.Location  = New-Object System.Drawing.Point($bbX, $bbY)
$overlay.Controls.Add($backBtn)

$backBtn.Add_Click({
    $overlay.TopMost = $false
    $hwnd = [PracticeEnforcer]::FindPracticeWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        [PracticeEnforcer]::BringPracticeToFront()
    } else {
        Start-Process $URL
    }
})

# ---- 1秒タイマー ----
$ticker          = New-Object System.Windows.Forms.Timer
$ticker.Interval = 1000

$ticker.Add_Tick({
    $title  = [PracticeEnforcer]::GetForegroundTitle()
    $onSite = $title -match "タイピング練習"

    if ($onSite) {
        if ($overlay.Visible) {
            $overlay.Hide()
            $timerForm.TopMost = $true
        }
        if ($script:secsLeft -gt 0) {
            $m = [math]::Floor($script:secsLeft / 60)
            $s = $script:secsLeft % 60
            $timerLabel.Text      = "{0}:{1:D2}" -f $m, $s
            $timerLabel.ForeColor = if ($script:secsLeft -le 15) { $COL_GREEN } else { $COL_ORANGE }
            $progBar.Value        = $PRACTICE_SEC - $script:secsLeft
            $script:secsLeft--
        } else {
            $script:done = $true
            $ticker.Stop()
            [PracticeEnforcer]::UninstallHook()
            $timerLabel.Text      = "完了！"
            $timerLabel.ForeColor = $COL_GREEN
            $progBar.Value        = $PRACTICE_SEC
            $miniMsg.Text         = "お疲れ様！"
            $script:closeTimer = New-Object System.Windows.Forms.Timer
            $script:closeTimer.Interval = 3000
            $script:closeTimer.Add_Tick({
                $script:closeTimer.Stop()
                $overlay.Close()
                $timerForm.Close()
            })
            $script:closeTimer.Start()
        }
    } else {
        $timerForm.TopMost = $false
        if (-not $overlay.Visible) { $overlay.Show() }
        $overlay.TopMost = $true
        $overlay.BringToFront()
    }
})

$timerForm.Add_Shown({ $ticker.Start() })
[System.Windows.Forms.Application]::Run($timerForm)
