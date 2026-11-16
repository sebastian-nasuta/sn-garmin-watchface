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

        // 1. Top: Notifications + Alarms (left) | SN Logo (center) | Battery (right)
        var logoY = (h * 0.085).toNumber();
        var topCenterY = logoY + 40;
        var leftRightEdgeX = cx - 58;
        var rightStartX = cx + 58;
        if (_logo != null) {
            var logo = _logo as WatchUi.BitmapResource;
            var halfLogoW = logo.getWidth() / 2;
            var logoX = cx - halfLogoW;
            dc.drawBitmap(logoX, logoY, logo);
            topCenterY = logoY + (logo.getHeight() / 2);
            leftRightEdgeX = cx - halfLogoW - 18;
            rightStartX = cx + halfLogoW + 18;
        }
        drawNotifications(dc, leftRightEdgeX, topCenterY - 14);
        drawAlarms(dc, leftRightEdgeX, topCenterY + 14);
        drawBattery(dc, rightStartX, topCenterY);

        // 2. Center: Digital Time
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx,
            (h * 0.43).toNumber(),
            Graphics.FONT_NUMBER_THAI_HOT,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // 3. Below Time: Date + Weather Icon + Temp
        drawDateAndWeather(dc, cx, (h * 0.62).toNumber());

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

    private function formatTemperature(conditions as Weather.CurrentConditions?) as String {
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

    private function drawDateAndWeather(dc as Dc, cx as Number, cy as Number) as Void {
        var dateText = formatDate();
        var conditions = Weather.getCurrentConditions();
        var tempText = formatTemperature(conditions);
        var condition = (conditions != null && conditions.condition != null) ? (conditions.condition as Number) : -1;

        var font = Graphics.FONT_SMALL;
        var iconH = (dc.getFontHeight(font) * 0.56).toNumber();
        if (iconH < 14) { iconH = 14; }
        var iconW = (iconH * 1.35).toNumber();
        var sectionGap = 14;
        var iconGap = 7;

        var dateW = dc.getTextWidthInPixels(dateText, font);
        var tempW = dc.getTextWidthInPixels(tempText, font);
        var totalW = dateW + sectionGap + iconW + iconGap + tempW;
        var x = cx - (totalW / 2);

        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            cy,
            font,
            dateText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        x += dateW + sectionGap;

        drawWeatherIcon(dc, x, cy, iconW, iconH, condition);
        x += iconW + iconGap;

        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            cy,
            font,
            tempText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawWeatherIcon(dc as Dc, x as Number, cy as Number, w as Number, h as Number, condition as Number) as Void {
        var cx = x + (w / 2);

        // Clear / Sunny
        if (condition == Weather.CONDITION_CLEAR ||
            condition == Weather.CONDITION_FAIR ||
            condition == Weather.CONDITION_MOSTLY_CLEAR) {
            var r = (h * 0.28).toNumber();
            if (r < 3) { r = 3; }
            dc.setColor(0xF59E0B, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            dc.setPenWidth(2);
            var rayOut = (h * 0.48).toNumber();
            var rayIn = r + 2;
            dc.drawLine(cx, cy - rayOut, cx, cy - rayIn);
            dc.drawLine(cx, cy + rayIn, cx, cy + rayOut);
            dc.drawLine(cx - rayOut, cy, cx - rayIn, cy);
            dc.drawLine(cx + rayIn, cy, cx + rayOut, cy);
            dc.setPenWidth(1);
            return;
        }

        // Partly Cloudy
        if (condition == Weather.CONDITION_PARTLY_CLOUDY ||
            condition == Weather.CONDITION_PARTLY_CLEAR ||
            condition == Weather.CONDITION_MOSTLY_CLOUDY) {
            dc.setColor(0xF59E0B, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + (w * 0.68).toNumber(), cy - (h * 0.22).toNumber(), (h * 0.22).toNumber());
            drawCloudShape(dc, cx - 1, cy + 2, w - 2, (h * 0.72).toNumber(), Graphics.COLOR_WHITE);
            return;
        }

        // Rain / Showers
        if (condition == Weather.CONDITION_RAIN ||
            condition == Weather.CONDITION_LIGHT_RAIN ||
            condition == Weather.CONDITION_HEAVY_RAIN ||
            condition == Weather.CONDITION_SHOWERS ||
            condition == Weather.CONDITION_LIGHT_SHOWERS ||
            condition == Weather.CONDITION_HEAVY_SHOWERS ||
            condition == Weather.CONDITION_CHANCE_OF_SHOWERS) {
            drawCloudShape(dc, cx, cy - 2, w, (h * 0.65).toNumber(), COLOR_MUTED);
            dc.setColor(0x38BDF8, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            var dropTop = cy + 2;
            var dropBot = cy + (h / 2);
            dc.drawLine(cx - 4, dropTop, cx - 6, dropBot);
            dc.drawLine(cx + 1, dropTop, cx - 1, dropBot);
            dc.drawLine(cx + 6, dropTop, cx + 4, dropBot);
            dc.setPenWidth(1);
            return;
        }

        // Thunderstorm
        if (condition == Weather.CONDITION_THUNDERSTORMS ||
            condition == Weather.CONDITION_SCATTERED_THUNDERSTORMS ||
            condition == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS) {
            drawCloudShape(dc, cx, cy - 2, w, (h * 0.65).toNumber(), COLOR_MUTED);
            dc.setColor(0xF59E0B, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(cx + 1, cy + 1, cx - 2, cy + 4);
            dc.drawLine(cx - 2, cy + 4, cx + 2, cy + 4);
            dc.drawLine(cx + 2, cy + 4, cx - 1, cy + (h / 2));
            dc.setPenWidth(1);
            return;
        }

        // Snow / Sleet / Hail
        if (condition == Weather.CONDITION_SNOW ||
            condition == Weather.CONDITION_LIGHT_SNOW ||
            condition == Weather.CONDITION_HEAVY_SNOW ||
            condition == Weather.CONDITION_RAIN_SNOW ||
            condition == Weather.CONDITION_HAIL ||
            condition == Weather.CONDITION_ICE ||
            condition == Weather.CONDITION_FREEZING_RAIN) {
            drawCloudShape(dc, cx, cy - 2, w, (h * 0.65).toNumber(), COLOR_MUTED);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var snowY = cy + (h * 0.35).toNumber();
            dc.fillCircle(cx - 4, snowY, 1);
            dc.fillCircle(cx + 1, snowY + 1, 1);
            dc.fillCircle(cx + 5, snowY - 1, 1);
            return;
        }

        // Windy
        if (condition == Weather.CONDITION_WINDY) {
            dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(x + 2, cy - 3, x + w - 4, cy - 3);
            dc.drawLine(x, cy + 1, x + w - 1, cy + 1);
            dc.drawLine(x + 3, cy + 5, x + w - 3, cy + 5);
            dc.setPenWidth(1);
            return;
        }

        // Default: Cloudy / Fog / Unknown
        drawCloudShape(dc, cx, cy, w, (h * 0.72).toNumber(), COLOR_MUTED);
    }

    private function drawCloudShape(dc as Dc, cx as Number, cy as Number, w as Number, h as Number, color as Number) as Void {
        var baseH = (h * 0.55).toNumber();
        var baseY = cy + (h / 2) - baseH;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - (w / 2), baseY, w, baseH, (baseH / 2).toNumber());
        dc.fillCircle(cx - (w * 0.14).toNumber(), baseY, (w * 0.24).toNumber());
        dc.fillCircle(cx + (w * 0.14).toNumber(), baseY + 1, (w * 0.18).toNumber());
    }

    private function drawSteps(dc as Dc, cx as Number, w as Number, h as Number) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = (info.steps != null) ? (info.steps as Number) : 0;
        var goal = (info.stepGoal != null && (info.stepGoal as Number) > 0) ? (info.stepGoal as Number) : 10000;

        var ratio = steps.toFloat() / goal.toFloat();
        if (ratio > 1.0) {
            ratio = 1.0;
        }

        var labelY = (h * 0.74).toNumber();
        var stepsText = steps.toString();
        var iconH = getIconHeight(dc);
        var iconW = iconH;
        var gap = 8;
        var textW = dc.getTextWidthInPixels(stepsText, Graphics.FONT_XTINY);
        var startX = cx - ((iconW + gap + textW) / 2);

        drawStepsIcon(dc, startX, labelY, iconW, iconH);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            startX + iconW + gap,
            labelY,
            Graphics.FONT_XTINY,
            stepsText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );

        var fillColor = (ratio >= 1.0) ? Graphics.COLOR_WHITE : COLOR_ACCENT;
        drawProgressBar(dc, cx, (h * 0.78).toNumber(), (w * 0.42).toNumber(), ratio, fillColor);
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

        var labelY = (h * 0.85).toNumber();
        var iconH = getIconHeight(dc);
        var iconW = (iconH * 1.25).toNumber();
        var gap = 7;
        var textW = dc.getTextWidthInPixels(stressText, Graphics.FONT_XTINY);
        var x = cx - ((iconW + gap + textW) / 2);

        drawStressIcon(dc, x, labelY, iconW, iconH, stressColor);

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
        drawProgressBar(dc, cx, (h * 0.89).toNumber(), (w * 0.28).toNumber(), ratio, stressColor);
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

        var iconH = getIconHeight(dc);
        var iconW = (iconH * 1.35).toNumber();
        var gap = 7;
        var textW = dc.getTextWidthInPixels(notifText, Graphics.FONT_XTINY);
        var x = rightEdgeX - (iconW + gap + textW);

        var iconColor = (notifications > 0) ? COLOR_ACCENT : COLOR_MUTED;
        var textColor = (notifications > 0) ? Graphics.COLOR_WHITE : COLOR_MUTED;
        drawNotificationIcon(dc, x, cy, iconW, iconH, iconColor);

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

        var iconH = getIconHeight(dc);
        var iconW = iconH + 2;
        var gap = 7;
        var textW = dc.getTextWidthInPixels(alarmText, Graphics.FONT_XTINY);
        var x = rightEdgeX - (iconW + gap + textW);

        var iconColor = (alarms > 0) ? 0xF59E0B : COLOR_MUTED;
        var textColor = (alarms > 0) ? Graphics.COLOR_WHITE : COLOR_MUTED;
        drawAlarmIcon(dc, x, cy, iconW, iconH, iconColor);

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + iconW + gap,
            cy,
            Graphics.FONT_XTINY,
            alarmText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawAlarmIcon(dc as Dc, x as Number, cy as Number, w as Number, h as Number, color as Number) as Void {
        var r = ((h - 4) / 2).toNumber();
        var cx = x + (w / 2);
        var bodyY = cy + 1;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        // Clean clock face
        dc.drawCircle(cx, bodyY, r);
        // Minimalist 12:15 hands
        dc.drawLine(cx, bodyY, cx, bodyY - (r * 0.55).toNumber());
        dc.drawLine(cx, bodyY, cx + (r * 0.50).toNumber(), bodyY);
        // Detached symmetrical top alarm ears
        dc.drawLine(cx - r - 2, bodyY - r + 1, cx - r + 1, bodyY - r - 2);
        dc.drawLine(cx + r + 2, bodyY - r + 1, cx + r - 1, bodyY - r - 2);
        dc.setPenWidth(1);
    }

    private function drawBattery(dc as Dc, x as Number, cy as Number) as Void {
        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();
        var batText = battery.toString() + "%";

        var gap = 7;
        var batIconH = getIconHeight(dc);
        var batIconW = (batIconH * 1.75).toNumber();

        var batColor = 0x84CC16; // > 50% warm green
        if (battery <= 20) {
            batColor = COLOR_ACCENT; // <= 20% red
        } else if (battery <= 50) {
            batColor = 0xF59E0B; // 21-50% amber
        }

        // Battery icon + percentage
        var batIconY = cy - (batIconH / 2);
        dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(x, batIconY, batIconW - 3, batIconH);
        dc.setPenWidth(1);
        dc.fillRectangle(x + batIconW - 3, batIconY + (batIconH * 0.28).toNumber(), 3, (batIconH * 0.44).toNumber());

        var maxInnerW = batIconW - 9;
        var innerW = (maxInnerW * battery / 100.0).toNumber();
        if (innerW > 0) {
            dc.fillRectangle(x + 3, batIconY + 3, innerW, batIconH - 6);
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

    private function drawNotificationIcon(dc as Dc, x as Number, cy as Number, w as Number, h as Number, color as Number) as Void {
        var top = cy - (h / 2);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(x, top, w, h);
        dc.drawLine(x, top, x + (w / 2), cy + 1);
        dc.drawLine(x + w - 1, top, x + (w / 2), cy + 1);
        dc.setPenWidth(1);
    }

    private function drawStressIcon(dc as Dc, x as Number, cy as Number, w as Number, h as Number, color as Number) as Void {
        var halfH = (h / 2).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x, cy + 1, x + (w * 0.22).toNumber(), cy + 1);
        dc.drawLine(x + (w * 0.22).toNumber(), cy + 1, x + (w * 0.38).toNumber(), cy - halfH + 1);
        dc.drawLine(x + (w * 0.38).toNumber(), cy - halfH + 1, x + (w * 0.60).toNumber(), cy + halfH - 1);
        dc.drawLine(x + (w * 0.60).toNumber(), cy + halfH - 1, x + (w * 0.78).toNumber(), cy - (halfH * 0.4).toNumber());
        dc.drawLine(x + (w * 0.78).toNumber(), cy - (halfH * 0.4).toNumber(), x + w, cy + 1);
        dc.setPenWidth(1);
    }

    private function drawStepsIcon(dc as Dc, x as Number, cy as Number, w as Number, h as Number) as Void {
        var rx = (w * 0.18).toNumber();
        var ry = (h * 0.26).toNumber();
        var heelR = (w * 0.13).toNumber();
        if (rx < 2) { rx = 2; }
        if (ry < 3) { ry = 3; }
        if (heelR < 2) { heelR = 2; }

        dc.setColor(COLOR_MUTED, Graphics.COLOR_TRANSPARENT);
        // Left footprint
        dc.fillEllipse(x + (w * 0.28).toNumber(), cy - (h * 0.20).toNumber(), rx, ry);
        dc.fillCircle(x + (w * 0.28).toNumber(), cy + (h * 0.25).toNumber(), heelR);
        // Right footprint
        dc.fillEllipse(x + (w * 0.72).toNumber(), cy + (h * 0.02).toNumber(), rx, ry);
        dc.fillCircle(x + (w * 0.72).toNumber(), cy + (h * 0.44).toNumber(), heelR);
    }

    private function getIconHeight(dc as Dc) as Number {
        var h = (dc.getFontHeight(Graphics.FONT_XTINY) * 0.56).toNumber();
        return (h < 12) ? 12 : h;
    }

}
