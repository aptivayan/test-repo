import tkinter as tk
import webbrowser

URL = "https://manabi-gakushu.benesse.ne.jp/gakushu/typing/nihongonyuryoku.html"
PRACTICE_SECONDS = 60


class TypingEnforcer:
    def __init__(self):
        self.root = tk.Tk()
        self.seconds_left = PRACTICE_SECONDS
        self.bar_width = 500
        self._build_ui()
        webbrowser.open(URL)
        self._tick()

    def _build_ui(self):
        root = self.root
        root.title("タイピング練習 - 必須")
        root.attributes("-fullscreen", True)
        root.attributes("-topmost", True)
        root.configure(bg="#0d1117")
        root.protocol("WM_DELETE_WINDOW", self._deny_close)
        root.bind("<Escape>", lambda e: self._deny_close())

        frame = tk.Frame(root, bg="#0d1117")
        frame.place(relx=0.5, rely=0.5, anchor="center")

        tk.Label(
            frame,
            text="毎日のタイピング練習",
            font=("Meiryo UI", 32, "bold"),
            fg="#58a6ff",
            bg="#0d1117",
        ).pack(pady=(0, 10))

        tk.Label(
            frame,
            text="ブラウザでタイピング練習をしてください。\n1分間の練習が完了するとこの画面が消えます。",
            font=("Meiryo UI", 16),
            fg="#8b949e",
            bg="#0d1117",
        ).pack(pady=10)

        self.timer_label = tk.Label(
            frame,
            text="1:00",
            font=("Segoe UI", 96, "bold"),
            fg="#f0883e",
            bg="#0d1117",
        )
        self.timer_label.pack(pady=20)

        self.bar_canvas = tk.Canvas(
            frame,
            width=self.bar_width,
            height=16,
            bg="#21262d",
            highlightthickness=0,
        )
        self.bar_canvas.pack(pady=10)
        self.bar_fill = self.bar_canvas.create_rectangle(
            0, 0, 0, 16, fill="#f0883e", outline=""
        )

        self.status_label = tk.Label(
            frame, text="", font=("Meiryo UI", 13), fg="#f85149", bg="#0d1117"
        )
        self.status_label.pack(pady=10)

    def _deny_close(self):
        self.status_label.config(
            text="1分間の練習が完了するまで閉じることができません！"
        )
        self.root.after(3000, lambda: self.status_label.config(text=""))

    def _tick(self):
        if self.seconds_left > 0:
            m = self.seconds_left // 60
            s = self.seconds_left % 60
            self.timer_label.config(text=f"{m}:{s:02d}")

            elapsed = PRACTICE_SECONDS - self.seconds_left
            fill = int((elapsed / PRACTICE_SECONDS) * self.bar_width)
            self.bar_canvas.coords(self.bar_fill, 0, 0, fill, 16)

            # 残り15秒で緑に変わる
            if self.seconds_left <= 15:
                self.timer_label.config(fg="#3fb950")
                self.bar_canvas.itemconfig(self.bar_fill, fill="#3fb950")

            self.seconds_left -= 1
            self.root.after(1000, self._tick)
        else:
            self._finish()

    def _finish(self):
        self.timer_label.config(text="完了！", fg="#3fb950")
        self.bar_canvas.coords(self.bar_fill, 0, 0, self.bar_width, 16)
        self.status_label.config(
            text="タイピング練習お疲れ様でした！  3秒後に閉じます...",
            fg="#3fb950",
        )
        self.root.after(3000, self.root.destroy)

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    TypingEnforcer().run()
