package com.flowa.flowa.blocking

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import com.flowa.flowa.focus.FocusRuntime
import kotlin.math.abs

/**
 * The calm full-screen reminder shown when the user opens a blocked app during
 * a session. Two modes, read from [BlockerState]:
 *
 * - **Soft friction (default):** "Open anyway? You were focusing 🌱" with a ~5s
 *   pause before the "Open anyway" button becomes tappable. "Stay focused"
 *   returns home; "Open anyway" lets them proceed (and isn't re-blocked) — a
 *   gentle nudge, never a cage.
 * - **Strict (opt-in):** a firm wall with only "Go back" (the old behavior).
 *
 * Copy is localized to the app language (en / ru / uz). Built in code (no
 * AppCompat) using Flowa's Zen palette.
 */
class BlockingOverlayActivity : Activity() {

    companion object {
        const val EXTRA_BLOCKED_PACKAGE = "blockedPackage"

        /** Gentle pause before "Open anyway" becomes tappable (seconds). */
        private const val OPEN_DELAY_SECONDS = 5

        private const val CREAM = 0xFFF4F1EA.toInt()
        private const val FOREST = 0xFF4F6F4E.toInt()
        private const val SAGE = 0xFFCBD8BE.toInt()
        private const val TEXT_PRIMARY = 0xFF2D2D2A.toInt()
        private const val TEXT_SECONDARY = 0xFF8A887F.toInt()
        private const val TEXT_TERTIARY = 0xFFB5B2A8.toInt()
        private const val CARD = 0xFFFFFFFF.toInt()
        private const val SURFACE_MUTED = 0xFFEFEDE6.toInt()

        private val STICKERS = listOf("🍃", "🌱", "🧘", "🌿", "🌸", "☀️")
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var timeLeftView: TextView

    private var blockedPkg = ""
    private var strict = false
    private var lang = "en"
    private lateinit var s: Map<String, String>

    private var openButton: Button? = null
    private var openSecondsLeft = OPEN_DELAY_SECONDS

    private val ticker = object : Runnable {
        override fun run() {
            if (!BlockerState.active || BlockerState.isExpired()) {
                finishAndStop()
                return
            }
            timeLeftView.text = formatRemaining(BlockerState.millisRemaining())
            handler.postDelayed(this, 1000L)
        }
    }

    /** Counts down the soft "Open anyway" pause, enabling the button at zero. */
    private val openCountdown = object : Runnable {
        override fun run() {
            openSecondsLeft -= 1
            if (openSecondsLeft <= 0) {
                enableOpenButton()
            } else {
                openButton?.text = "${t("open_anyway")} ($openSecondsLeft)"
                handler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        blockedPkg = intent?.getStringExtra(EXTRA_BLOCKED_PACKAGE) ?: ""
        strict = BlockerState.strict
        lang = BlockerState.lang
        s = strings(lang)
        // The hard wall counts as a distraction on sight. Soft friction only
        // counts if they actually choose "Open anyway" (see onOpenAnyway), so
        // resisting the gentle reminder is never penalized.
        if (strict) FocusRuntime.incDistractingOpens(applicationContext)
        setContentView(buildContent(blockedPkg))
    }

    override fun onResume() {
        super.onResume()
        if (!BlockerState.active || BlockerState.isExpired()) {
            finishAndStop()
            return
        }
        BlockerState.overlayShowing = true
        handler.post(ticker)
        if (!strict) {
            openSecondsLeft = OPEN_DELAY_SECONDS
            disableOpenButton()
            handler.postDelayed(openCountdown, 1000L)
        }
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(ticker)
        handler.removeCallbacks(openCountdown)
        BlockerState.overlayShowing = false
    }

    @Deprecated("Back returns home, never to the blocked app")
    override fun onBackPressed() {
        goHome()
    }

    private fun buildContent(blockedPackage: String): View {
        val variant = abs(blockedPackage.hashCode())
        val sticker = STICKERS[variant % STICKERS.size]

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(CREAM)
            val pad = dp(28)
            setPadding(pad, pad, pad, pad)
            layoutParams = ViewGroup.LayoutParams(MATCH, MATCH)
        }

        root.addView(
            TextView(this).apply {
                text = sticker
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 40f)
                gravity = Gravity.CENTER
                background = circle(SAGE)
                val size = dp(104)
                layoutParams = LinearLayout.LayoutParams(size, size)
                val p = dp(20)
                setPadding(p, p, p, p)
            },
        )

        root.addView(spacer(dp(28)))
        root.addView(
            label(
                if (strict) t("strict_headline") else t("soft_headline"),
                26f,
                TEXT_PRIMARY,
                bold = true,
            ),
        )
        root.addView(spacer(dp(10)))
        root.addView(
            label(if (strict) t("strict_body") else t("soft_body"), 15f, TEXT_SECONDARY),
        )

        root.addView(spacer(dp(28)))
        root.addView(timeLeftCard())

        root.addView(spacer(dp(32)))
        if (strict) {
            root.addView(primaryButton(t("go_back")) { goHome() })
        } else {
            root.addView(primaryButton(t("stay_focused")) { goHome() })
            root.addView(spacer(dp(12)))
            root.addView(buildOpenAnywayButton())
        }

        return root
    }

    private fun buildOpenAnywayButton(): View {
        val button = Button(this).apply {
            isAllCaps = false
            setTextColor(FOREST)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            background = rounded(SURFACE_MUTED, dp(30).toFloat())
            layoutParams = LinearLayout.LayoutParams(MATCH, dp(56))
            setOnClickListener { onOpenAnyway() }
        }
        openButton = button
        disableOpenButton()
        return button
    }

    private fun disableOpenButton() {
        openButton?.apply {
            isEnabled = false
            alpha = 0.45f
            setTextColor(TEXT_TERTIARY)
            text = "${t("open_anyway")} ($openSecondsLeft)"
        }
    }

    private fun enableOpenButton() {
        openButton?.apply {
            isEnabled = true
            alpha = 1f
            setTextColor(FOREST)
            text = t("open_anyway")
        }
    }

    private fun onOpenAnyway() {
        // Let this app through for the rest of the session (don't re-block), and
        // gently note that proceeding affects the honest-focus session.
        BlockerState.allow(blockedPkg)
        FocusRuntime.incDistractingOpens(applicationContext)
        Toast.makeText(this, t("note"), Toast.LENGTH_SHORT).show()
        handler.removeCallbacks(ticker)
        handler.removeCallbacks(openCountdown)
        BlockerState.overlayShowing = false
        // Finish WITHOUT going home → returns the user to the app they opened.
        finish()
        overridePendingTransition(0, 0)
    }

    private fun timeLeftCard(): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = rounded(CARD, dp(20).toFloat())
            val ph = dp(28)
            val pv = dp(20)
            setPadding(ph, pv, ph, pv)
        }

        val title = BlockerState.taskTitle
        if (title.isNotBlank()) {
            card.addView(label(t("focusing_on"), 11f, TEXT_SECONDARY))
            card.addView(spacer(dp(4)))
            card.addView(label(title, 16f, TEXT_PRIMARY, bold = true))
            card.addView(spacer(dp(14)))
        }

        card.addView(label(t("time_left"), 11f, TEXT_SECONDARY))
        card.addView(spacer(dp(6)))
        timeLeftView = TextView(this).apply {
            text = formatRemaining(BlockerState.millisRemaining())
            setTextColor(FOREST)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 34f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }
        card.addView(timeLeftView)
        return card
    }

    private fun primaryButton(text: String, onClick: () -> Unit): View {
        return Button(this).apply {
            this.text = text
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            background = rounded(FOREST, dp(30).toFloat())
            layoutParams = LinearLayout.LayoutParams(MATCH, dp(56))
            setOnClickListener { onClick() }
        }
    }

    private fun goHome() {
        val home = android.content.Intent(android.content.Intent.ACTION_MAIN).apply {
            addCategory(android.content.Intent.CATEGORY_HOME)
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(home)
        finish()
        overridePendingTransition(0, 0)
    }

    private fun finishAndStop() {
        handler.removeCallbacks(ticker)
        handler.removeCallbacks(openCountdown)
        BlockerState.overlayShowing = false
        finish()
        overridePendingTransition(0, 0)
    }

    // ---- Localized copy ----

    private fun t(key: String): String = s[key] ?: key

    private fun strings(lang: String): Map<String, String> = when (lang) {
        "ru" -> mapOf(
            "soft_headline" to "Всё равно открыть?",
            "soft_body" to "Вы были сосредоточены 🌱 Сделайте вдох — можно " +
                "остаться или открыть.",
            "strict_headline" to "Помогаем сохранить фокус",
            "strict_body" to "Это приложение на паузе до конца сессии фокуса.",
            "stay_focused" to "Остаться в фокусе",
            "open_anyway" to "Всё равно открыть",
            "go_back" to "Назад",
            "focusing_on" to "ФОКУС НА",
            "time_left" to "ДО КОНЦА СЕССИИ",
            "note" to "Отмечено — сессия фокуса продолжается 🌱",
        )
        "uz" -> mapOf(
            "soft_headline" to "Baribir ochilsinmi?",
            "soft_body" to "Siz diqqatda edingiz 🌱 Nafas oling — qolishingiz " +
                "yoki ochishingiz mumkin.",
            "strict_headline" to "Diqqatda qolishingizga yordam beramiz",
            "strict_body" to "Bu ilova diqqat seansi tugaguncha pauzada.",
            "stay_focused" to "Diqqatda qolish",
            "open_anyway" to "Baribir ochish",
            "go_back" to "Orqaga",
            "focusing_on" to "DIQQAT MARKAZIDA",
            "time_left" to "SEANS TUGASHIGA",
            "note" to "Belgilandi — diqqat seansi davom etmoqda 🌱",
        )
        else -> mapOf(
            "soft_headline" to "Open anyway?",
            "soft_body" to "You were focusing 🌱 Take a breath — you can stay, " +
                "or open it.",
            "strict_headline" to "Helping you stay focused",
            "strict_body" to "This app is paused until your focus session ends.",
            "stay_focused" to "Stay focused",
            "open_anyway" to "Open anyway",
            "go_back" to "Go back",
            "focusing_on" to "FOCUSING ON",
            "time_left" to "TIME LEFT IN SESSION",
            "note" to "Noted — your focus session continues 🌱",
        )
    }

    // ---- Small view helpers ----

    private fun label(
        text: String,
        sizeSp: Float,
        color: Int,
        bold: Boolean = false,
    ): TextView = TextView(this).apply {
        this.text = text
        setTextColor(color)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        gravity = Gravity.CENTER
        if (bold) typeface = Typeface.create("sans-serif", Typeface.BOLD)
    }

    private fun spacer(height: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(MATCH, height)
    }

    private fun circle(color: Int): GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
    }

    private fun rounded(color: Int, radius: Float): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = radius
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun formatRemaining(millis: Long): String {
        val totalSeconds = millis / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    private val MATCH get() = ViewGroup.LayoutParams.MATCH_PARENT
}
