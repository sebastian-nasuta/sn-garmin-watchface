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

        // 1. Top: Notifications + Alarms (left) + SN Logo (center) + Battery (right)
        var logoY = (h * 0.10).toNumber();
        var topCenterY = logoY + 32;
        var leftRightEdgeX = cx - 50;
        var batX = cx + 50;
        if (_logo != null) {
            var logo = _logo as WatchUi.BitmapResource;
            var halfLogoW = logo.getWidth() / 2;
            var logoX = cx - halfLogoW;
            dc.drawBitmap(logoX, logoY, logo);
            topCenterY = logoY + (logo.getHeight() / 2);
            leftRightEdgeX = cx - halfLogoW - 18;
            batX = cx + halfLogoW + 18;
        }
        drawNotifications(dc, leftRightEdgeX, topCenterY - 13);
        drawAlarms(dc, leftRightEdgeX, topCenterY + 13);
        drawBattery(dc, batX, topCenterY);

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

        // 5. Bottom: Stress + Minimalist Progress Bar
        drawStress(dc, cx, w, h);
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

        var labelY = (h * 0.71).toNumber();
        var stepsText = steps.toString();
        var iconW = 16;
        var gap = 7;
        var textW = dc.getTextWidthInPixels(stepsText, Graphics.FONT_XTINY);
        var startX = cx - ((iconW + gap + textW) / 2);

        drawStepsIcon(dc, startX, labelY);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            startX + iconW + gap,
            labelY,
            Graphics.FONT_XTINY,
            stepsText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var fillColor = (ratio >= 1.0) ? Graphics.COLOR_WHITE : COLOR_ACCENT;
        drawProgressBar(dc, cx, (h * 0.75).toNumber(), (w * 0.42).toNumber(), ratio, fillColor);
    }

    private function drawStress(dc as Dc, cx as Number, w as Number, h as Number) as Void {
        var actInfo = ActivityMonitor.getInfo();
        var stress = actInfo.stressScore;
        var hasStress = (stress != null && (stress as Number) >= 0);
        var stressVal = hasStress ? (stress as Number) : 0;
        var stressText = hasStress ? stressVal.toString() : "--";

        var stressColor = COLOR_MUTED;
        if (hasStress) {
            if (stressVal >= 75) {
                stressColor = COLOR_ACCENT;
            } else if (stressVal > 25) {
                stressColor = Graphics.COLOR_WHITE;
            }
        }

        var labelY = (h * 0.83).toNumber();
        var iconW = 14;
        var gap = 6;
        var textW = dc.getTextWidthInPixels(stressText, Graphics.FONT_XTINY);
        var x = cx - ((iconW + gap + textW) / 2);

        drawStressIcon(dc, x, labelY, stressColor);

        dc.setColor(stressColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + iconW + gap,
            labelY,
            Graphics.FONT_XTINY,
            stressText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var ratio = hasStress ? (stressVal.toFloat() / 100.0) : 0.0;
        if (ratio > 1.0) {
            ratio = 1.0;
        }
        drawProgressBar(dc, cx, (h * 0.87).toNumber(), (w * 0.28).toNumber(), ratio, stressColor);
    }

    private function drawProgressBar(dc as Dc, cx as Number, barY as Number, barW as Number, ratio as Float, fillColor as Number) as Void {
        var barH = 4;
        var barX = cx - (barW / 2);

        dc.setColor(COLOR_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 2);

        var fillW = (barW * ratio).toNumber();
        if (fillW > 0) {
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, barY, fillW, barH, 2);
        }
    }

    private function drawNotifications(dc as Dc, rightEdgeX as Number, cy as Number) as Void {
        var settings = System.getDeviceSettings();
        var notifications = (settings.notificationCount != null) ? (settings.notificationCount as Number) : 0;
        var notifText = notifications.toString();

        var iconW = 14;
        var gap = 6;
        var textW = dc.getTextWidthInPixels(notifText, Graphics.FONT_XTINY);
        var x = rightEdgeX - (iconW + gap + textW);

        var iconColor = (notifications > 0) ? COLOR_ACCENT : COLOR_MUTED;
        var textColor = (notifications > 0) ? Graphics.COLOR_WHITE : COLOR_MUTED;
        drawNotificationIcon(dc, x, cy, iconColor);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + iconW + gap,
            cy,
            Graphics.FONT_XTINY,
            notifText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawAlarms(dc as Dc, rightEdgeX as Number, cy as Number) as Void {
        var settings = System.getDeviceSettings();
        var alarms = (settings.alarmCount != null) ? (settings.alarmCount as Number) : 0;
        var alarmText = alarms.toString();

        var iconW = 14;
        var gap = 6;
        var textW = dc.getTextWidthInPixels(alarmText, Graphics.FONT_XTINY);
        var x = rightEdgeX - (iconW + gap + textW);

        var iconColor = (alarms > 0) ? 0xF59E0B : COLOR_MUTED;
        var textColor = (alarms > 0) ? Graphics.COLOR_WHITE : COLOR_MUTED;
        drawAlarmIcon(dc, x, cy, iconColor);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + iconW + gap,
            cy,
            Graphics.FONT_XTINY,
            alarmText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawAlarmIcon(dc as Dc, x as Number, cy as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x + 7, cy + 1, 5);
        dc.drawLine(x + 7, cy + 1, x + 7, cy - 2);
        dc.drawLine(x + 7, cy + 1, x + 9, cy + 1);
        dc.drawLine(x + 2, cy - 5, x + 4, cy - 3);
        dc.drawLine(x + 12, cy - 5, x + 10, cy - 3);
    }

    private function drawBattery(dc as Dc, x as Number, cy as Number) as Void {
        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();
        var batText = battery.toString() + "%";

        var gap = 6;
        var batIconW = 22;
        var batIconH = 11;

        var batColor = 0x84CC16; // > 50% warm green
        if (battery <= 20) {
            batColor = COLOR_ACCENT; // <= 20% red
        } else if (battery <= 50) {
            batColor = 0xF59E0B; // 21-50% amber
        }

        // Battery icon + percentage
        var batIconY = cy - (batIconH / 2);
        dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, batIconY, batIconW - 2, batIconH);
        dc.fillRectangle(x + batIconW - 2, batIconY + 3, 2, batIconH - 6);

        var innerW = ((batIconW - 6) * battery / 100.0).toNumber();
        if (innerW > 0) {
            dc.fillRectangle(x + 2, batIconY + 2, innerW, batIconH - 4);
        }

        dc.setColor((battery <= 20) ? COLOR_ACCENT : COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + batIconW + gap,
            cy,
            Graphics.FONT_XTINY,
            batText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawNotificationIcon(dc as Dc, x as Number, cy as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x, cy - 5, 14, 10);
        dc.drawLine(x, cy - 5, x + 7, cy + 1);
        dc.drawLine(x + 13, cy - 5, x + 7, cy + 1);
    }

    private function drawStressIcon(dc as Dc, x as Number, cy as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, cy + 1, x + 3, cy + 1);
        dc.drawLine(x + 3, cy + 1, x + 5, cy - 5);
        dc.drawLine(x + 5, cy - 5, x + 8, cy + 5);
        dc.drawLine(x + 8, cy + 5, x + 11, cy - 2);
        dc.drawLine(x + 11, cy - 2, x + 14, cy + 1);
    }

    private function drawStepsIcon(dc as Dc, x as Number, cy as Number) as Void {
        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        // Left footprint
        dc.fillEllipse(x + 4, cy - 3, 3, 4);
        dc.fillCircle(x + 4, cy + 4, 2);
        // Right footprint
        dc.fillEllipse(x + 12, cy, 3, 4);
        dc.fillCircle(x + 12, cy + 7, 2);
    }

}
