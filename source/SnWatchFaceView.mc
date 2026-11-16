import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class SnWatchFaceView extends WatchUi.WatchFace {

    private var _isSleeping as Boolean = false;
    private var _logo as WatchUi.BitmapResource?;

    private const COLOR_MUTED = 0x888888;
    private const COLOR_TRACK = 0x262626;
    private const COLOR_ACCENT = 0xE10600;
    private const COLOR_AOD = 0x555555;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _logo = WatchUi.loadResource(Rez.Drawables.SnLogo) as WatchUi.BitmapResource;
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clockTime = System.getClockTime();
        var timeStr = formatTime(clockTime);

        if (_isSleeping) {
            drawAod(dc, cx, h, clockTime, timeStr);
            return;
        }

        // 1. Top: SN Logo
        if (_logo != null) {
            var logo = _logo as WatchUi.BitmapResource;
            var logoX = cx - (logo.getWidth() / 2);
            var logoY = (h * 0.10).toNumber();
            dc.drawBitmap(logoX, logoY, logo);
        }

        // 2. Center: Digital Time
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            (h * 0.43).toNumber(),
            Graphics.FONT_NUMBER_THAI_HOT,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // 3. Below Time: Date + Weather
        var infoLine = formatDate() + "  ·  " + formatTemperature();
        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            (h * 0.62).toNumber(),
            Graphics.FONT_SMALL,
            infoLine,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // 4. Steps + Minimalist Progress Bar
        drawSteps(dc, cx, w, h);

        // 5. Bottom: Battery
        drawBattery(dc, cx, h);
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        _isSleeping = false;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        _isSleeping = true;
        WatchUi.requestUpdate();
    }

    private function drawAod(dc as Dc, cx as Number, h as Number, clockTime as System.ClockTime, timeStr as String) as Void {
        // Subtle pixel shift every minute to prevent AMOLED burn-in
        var shiftY = ((clockTime.min % 5) - 2) * 2;
        dc.setColor(COLOR_AOD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            (h * 0.46).toNumber() + shiftY,
            Graphics.FONT_NUMBER_THAI_HOT,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function formatTime(clockTime as System.ClockTime) as String {
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours == 0) {
                hours = 12;
            } else if (hours > 12) {
                hours = hours - 12;
            }
        }
        return Lang.format("$1$:$2$", [
            hours.format("%02d"),
            clockTime.min.format("%02d")
        ]);
    }

    private function formatDate() as String {
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$ $2$ $3$", [
            now.day_of_week.toUpper(),
            now.day.format("%d"),
            now.month.toUpper()
        ]);
    }

    private function formatTemperature() as String {
        var conditions = Weather.getCurrentConditions();
        if (conditions == null || conditions.temperature == null) {
            return "--°";
        }
        var tempC = conditions.temperature as Number or Float;
        var units = System.getDeviceSettings().temperatureUnits;
        if (units == System.UNIT_STATUTE) {
            var tempF = ((tempC * 9.0) / 5.0 + 32.0).toNumber();
            return tempF.toString() + "°F";
        }
        return tempC.toNumber().toString() + "°C";
    }

    private function drawSteps(dc as Dc, cx as Number, w as Number, h as Number) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = (info.steps != null) ? (info.steps as Number) : 0;
        var goal = (info.stepGoal != null && (info.stepGoal as Number) > 0) ? (info.stepGoal as Number) : 10000;

        var ratio = steps.toFloat() / goal.toFloat();
        if (ratio > 1.0) {
            ratio = 1.0;
        }

        var labelY = (h * 0.72).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            labelY,
            Graphics.FONT_XTINY,
            steps.toString() + " STEPS",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var barW = (w * 0.42).toNumber();
        var barH = 4;
        var barX = cx - (barW / 2);
        var barY = (h * 0.77).toNumber();

        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 2);

        var fillW = (barW * ratio).toNumber();
        if (fillW > 0) {
            var fillColor = (ratio >= 1.0) ? Graphics.COLOR_WHITE : COLOR_ACCENT;
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, barY, fillW, barH, 2);
        }
    }

    private function drawBattery(dc as Dc, cx as Number, h as Number) as Void {
        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();
        var y = (h * 0.86).toNumber();

        // Compact battery icon + percentage centered
        var iconW = 22;
        var iconH = 11;
        var gap = 6;
        var text = battery.toString() + "%";
        var textW = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY);
        var totalW = iconW + gap + textW;
        var startX = cx - (totalW / 2);
        var iconY = y - (iconH / 2);

        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(startX, iconY, iconW - 2, iconH);
        dc.fillRectangle(startX + iconW - 2, iconY + 3, 2, iconH - 6);

        var innerW = ((iconW - 6) * battery / 100.0).toNumber();
        if (innerW > 0) {
            var batColor = (battery <= 20) ? COLOR_ACCENT : Graphics.COLOR_WHITE;
            dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(startX + 2, iconY + 2, innerW, iconH - 4);
        }

        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            startX + iconW + gap,
            y,
            Graphics.FONT_XTINY,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

}
