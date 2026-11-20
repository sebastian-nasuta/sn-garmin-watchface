import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
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
        drawBattery(dc, rightStartX, topCenterY, clockTime.sec);

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
        drawDateAndWeather(dc, cx, (h * 0.62).toNumber(), clockTime.sec);

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

    private function drawDateAndWeather(dc as Dc, cx as Number, cy as Number, sec as Number) as Void {
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

        drawWeatherIcon(dc, x, cy, iconW, iconH, condition, sec);
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

    private function drawWeatherIcon(dc as Dc, x as Number, cy as Number, w as Number, h as Number, condition as Number, sec as Number) as Void {
        var cx = x + (w / 2);

        // Clear / Sunny (static 8 main rays + pulsing intermediate rays)
        if (condition == Weather.CONDITION_CLEAR ||
            condition == Weather.CONDITION_FAIR ||
            condition == Weather.CONDITION_MOSTLY_CLEAR) {
            var r = (h * 0.31).toNumber();
            if (r < 4) { r = 4; }
            dc.setColor(0xF59E0B, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            dc.setPenWidth(2);
            var rayIn = r + 2;
            var rayOut = (h * 0.54).toNumber();
            var diagIn = (rayIn * 0.71).toNumber();
            var diagOut = (rayOut * 0.71).toNumber();
            // 8 static main rays (4 cardinal + 4 diagonal)
            dc.drawLine(cx, cy - rayOut, cx, cy - rayIn);
            dc.drawLine(cx, cy + rayIn, cx, cy + rayOut);
            dc.drawLine(cx - rayOut, cy, cx - rayIn, cy);
            dc.drawLine(cx + rayIn, cy, cx + rayOut, cy);
            dc.drawLine(cx - diagOut, cy - diagOut, cx - diagIn, cy - diagIn);
            dc.drawLine(cx + diagIn, cy - diagIn, cx + diagOut, cy - diagOut);
            dc.drawLine(cx - diagOut, cy + diagOut, cx - diagIn, cy + diagIn);
            dc.drawLine(cx + diagIn, cy + diagIn, cx + diagOut, cy + diagOut);

            // 8 smaller intermediate rays that pulse between small and medium (always visible)
            var medLen = rayOut - rayIn - 1;
            if (medLen < 4) { medLen = 4; }
            var smallLen = medLen - 2;
            var extraLen = (sec % 2 == 0) ? smallLen : medLen;
            var subOut = rayIn + extraLen;
            dc.setColor(0xFBBF24, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var i = 0; i < 8; i++) {
                var angle = (i * (Math.PI / 4.0)) + (Math.PI / 8.0);
                var cosA = Math.cos(angle);
                var sinA = Math.sin(angle);
                dc.drawLine(
                    cx + (rayIn * cosA).toNumber(),
                    cy + (rayIn * sinA).toNumber(),
                    cx + (subOut * cosA).toNumber(),
                    cy + (subOut * sinA).toNumber()
                );
            }
            dc.setPenWidth(1);
            return;
        }

        // Partly Cloudy (drifting cloud in front of amber sun)
        if (condition == Weather.CONDITION_PARTLY_CLOUDY ||
            condition == Weather.CONDITION_PARTLY_CLEAR ||
            condition == Weather.CONDITION_MOSTLY_CLOUDY) {
            var sunX = x + (w * 0.68).toNumber();
            var sunY = cy - (h * 0.22).toNumber();
            var sunR = (h * 0.34).toNumber();
            if (sunR < 5) { sunR = 5; }

            dc.setColor(0xF59E0B, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sunX, sunY, sunR);

            // Drifting foreground cloud
            var pcPhase = sec % 4;
            var pcDrift = (pcPhase == 0) ? -2 : ((pcPhase == 2) ? 2 : 0);
            drawCloudShape(dc, cx - 1 + pcDrift, cy + 2, w - 2, (h * 0.70).toNumber(), Graphics.COLOR_WHITE);
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
            drawCloudShape(dc, cx, cy - 5, w, (h * 0.52).toNumber(), COLOR_MUTED);
            dc.setColor(0x38BDF8, Graphics.COLOR_TRANSPARENT);
            var dropBaseY = cy + 6;
            drawRaindrop(dc, cx - 11, dropBaseY + ((sec % 3) * 2));
            drawRaindrop(dc, cx - 4,  dropBaseY + (((sec + 1) % 3) * 2));
            drawRaindrop(dc, cx + 4,  dropBaseY + (((sec + 2) % 3) * 2));
            drawRaindrop(dc, cx + 11, dropBaseY + (((sec + 1) % 3) * 2));
            return;
        }

        // Thunderstorm (organic non-sequential flashing bolts)
        if (condition == Weather.CONDITION_THUNDERSTORMS ||
            condition == Weather.CONDITION_SCATTERED_THUNDERSTORMS ||
            condition == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS) {
            // Bitmask per second: 1=left, 2=center, 4=right
            var mask = [2, 4, 1, 0, 5, 2, 0][sec % 7];
            var cloudColor = ((mask & 2) != 0) ? 0xA3A3A3 : COLOR_MUTED;
            drawCloudShape(dc, cx, cy - 5, w, (h * 0.52).toNumber(), cloudColor);

            if ((mask & 1) != 0) {
                dc.setColor(0xF59E0B, Graphics.COLOR_TRANSPARENT);
                drawLightningBolt(dc, cx - 9, cy + 2, 1.0);
            }
            if ((mask & 2) != 0) {
                dc.setColor(0xFEF08A, Graphics.COLOR_TRANSPARENT);
                drawLightningBolt(dc, cx, cy + 2, 1.35);
            }
            if ((mask & 4) != 0) {
                dc.setColor(0xF59E0B, Graphics.COLOR_TRANSPARENT);
                drawLightningBolt(dc, cx + 9, cy + 2, 1.0);
            }
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
            // 3 crystalline snowflakes gently floating & falling
            var sPhase = sec % 4;
            var bigSway = (sPhase == 0) ? -1 : ((sPhase == 2) ? 1 : 0);
            var bigDrop = (sec % 2 == 0) ? 0 : 1;
            drawSnowflake(dc, cx - 9 + bigSway, cy + 1 + bigDrop, 10, Graphics.COLOR_WHITE);

            var medSway = (sec % 2 == 0) ? 1 : -1;
            var medDrop = (sec % 3) * 2;
            drawSnowflake(dc, cx + 11 + medSway, cy - 8 + medDrop, 6, 0xBAE6FD);

            var smlSway = (sec % 2 == 0) ? -1 : 1;
            var smlDrop = ((sec + 1) % 3) * 2 - 2;
            drawSnowflake(dc, cx + 7 + smlSway, cy + 9 + smlDrop, 4, 0xBAE6FD);
            return;
        }

        // Windy (moving gusts + blowing leaves)
        if (condition == Weather.CONDITION_WINDY) {
            var sway = (sec % 2 == 0) ? 0 : 2;
            dc.setColor(0xCBD5E1, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);

            // Top gust (curls up)
            var topEndX = x + w - 8 + sway;
            dc.drawLine(x + 1 + sway, cy - 5, topEndX, cy - 5);
            dc.drawArc(topEndX, cy - 8, 3, Graphics.ARC_COUNTER_CLOCKWISE, 270, 135);

            // Middle gust (longest, opposite sway)
            var midSway = 2 - sway;
            var midEndX = x + w - 5 + midSway;
            dc.drawLine(x + midSway, cy, midEndX, cy);
            dc.drawArc(midEndX, cy - 3, 3, Graphics.ARC_COUNTER_CLOCKWISE, 270, 120);

            // Bottom gust (curls down)
            var botEndX = x + w - 8 + sway;
            dc.drawLine(x + 3 + sway, cy + 5, botEndX, cy + 5);
            dc.drawArc(botEndX, cy + 8, 3, Graphics.ARC_CLOCKWISE, 90, 225);
            dc.setPenWidth(1);

            // Two leaves drifting left-to-right in the wind
            var step1 = sec % 5;
            var lx1 = x + 2 + ((w - 4) * step1 / 4).toNumber();
            var ly1 = cy - 3 + ((step1 % 2 == 0) ? -2 : 1);
            drawLeaf(dc, lx1, ly1, 0x84CC16);

            var step2 = (sec + 2) % 5;
            var lx2 = x + 2 + ((w - 4) * step2 / 4).toNumber();
            var ly2 = cy + 3 + ((step2 % 2 == 0) ? 2 : -1);
            drawLeaf(dc, lx2, ly2, 0xF59E0B);
            return;
        }

        // Fog / Mist / Hazy (cloud + gently drifting layered mist banks)
        if (condition == Weather.CONDITION_FOG ||
            condition == Weather.CONDITION_MIST ||
            condition == Weather.CONDITION_HAZY ||
            condition == Weather.CONDITION_SMOKE ||
            condition == Weather.CONDITION_DUST) {
            var fogPhase = sec % 4;
            var fogDrift = (fogPhase == 0) ? -2 : ((fogPhase == 2) ? 2 : 0);
            drawCloudShape(dc, cx, cy - 5, (w * 0.86).toNumber(), (h * 0.48).toNumber(), COLOR_MUTED);
            dc.setColor(0xA3A3A3, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + 2 + fogDrift, cy + 3, w - 5, 2, 1);
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + 4 - fogDrift, cy + 7, w - 8, 2, 1);
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x + 3 + fogDrift, cy + 11, w - 6, 2, 1);
            return;
        }

        // Default: Cloudy / Unknown (animated parallax clouds)
        var cloudPhase = sec % 4;
        var drift = (cloudPhase == 0) ? -2 : ((cloudPhase == 2) ? 2 : 0);
        // Darker background cloud drifting opposite
        drawCloudShape(dc, cx + 3 - drift, cy - 3, (w * 0.78).toNumber(), (h * 0.54).toNumber(), 0x555555);
        // Lighter foreground cloud drifting gently
        drawCloudShape(dc, cx - 1 + drift, cy + 2, (w * 0.88).toNumber(), (h * 0.62).toNumber(), COLOR_MUTED);
    }

    private function drawLeaf(dc as Dc, lx as Number, ly as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [lx - 3, ly + 1],
            [lx,     ly - 2],
            [lx + 3, ly - 1],
            [lx,     ly + 2]
        ]);
    }

    private function drawSnowflake(dc as Dc, sx as Number, sy as Number, r as Number, color as Number) as Void {
        var dx = (r * 0.87).toNumber();
        var dy = (r * 0.50).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // 6 main crystal arms
        dc.drawLine(sx, sy - r, sx, sy + r);
        dc.drawLine(sx - dx, sy - dy, sx + dx, sy + dy);
        dc.drawLine(sx - dx, sy + dy, sx + dx, sy - dy);

        // Delicate V-shaped crystal branches for medium & large snowflakes
        if (r >= 5) {
            var b = (r >= 7) ? 2 : 1;
            var vPos = (r * 0.62).toNumber();
            // Top & bottom V-branches
            dc.drawLine(sx - b, sy - vPos - b, sx, sy - vPos);
            dc.drawLine(sx + b, sy - vPos - b, sx, sy - vPos);
            dc.drawLine(sx - b, sy + vPos + b, sx, sy + vPos);
            dc.drawLine(sx + b, sy + vPos + b, sx, sy + vPos);

            // Diagonal V-branches
            var bx = (dx * 0.60).toNumber();
            var by = (dy * 0.60).toNumber();
            // Upper-left
            dc.drawLine(sx - bx, sy - by, sx - bx - 1, sy - by - b - 1);
            dc.drawLine(sx - bx, sy - by, sx - bx - b - 1, sy - by + 1);
            // Lower-right
            dc.drawLine(sx + bx, sy + by, sx + bx + 1, sy + by + b + 1);
            dc.drawLine(sx + bx, sy + by, sx + bx + b + 1, sy + by - 1);
            // Lower-left
            dc.drawLine(sx - bx, sy + by, sx - bx - 1, sy + by + b + 1);
            dc.drawLine(sx - bx, sy + by, sx - bx - b - 1, sy + by - 1);
            // Upper-right
            dc.drawLine(sx + bx, sy - by, sx + bx + 1, sy - by - b - 1);
            dc.drawLine(sx + bx, sy - by, sx + bx + b + 1, sy - by + 1);
        }
    }

    private function drawLightningBolt(dc as Dc, bx as Number, topY as Number, scale as Float) as Void {
        dc.fillPolygon([
            [bx + (2 * scale).toNumber(), topY],
            [bx - (3 * scale).toNumber(), topY + (5 * scale).toNumber()],
            [bx,                          topY + (5 * scale).toNumber()],
            [bx - (2 * scale).toNumber(), topY + (10 * scale).toNumber()],
            [bx + (3 * scale).toNumber(), topY + (4 * scale).toNumber()],
            [bx,                          topY + (4 * scale).toNumber()]
        ]);
    }

    private function drawRaindrop(dc as Dc, dx as Number, dy as Number) as Void {
        dc.fillCircle(dx, dy + 1, 2);
        dc.fillPolygon([
            [dx, dy - 3],
            [dx - 2, dy + 1],
            [dx + 2, dy + 1]
        ]);
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

    private function drawBattery(dc as Dc, x as Number, cy as Number, sec as Number) as Void {
        var stats = System.getSystemStats();
        var battery = stats.battery.toNumber();
        var isCharging = (stats has :charging && stats.charging != null && stats.charging == true);
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

        // Battery icon outline + terminal
        var batIconY = cy - (batIconH / 2);
        var bodyW = batIconW - 3;
        dc.setColor(batColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(x, batIconY, bodyW, batIconH);
        dc.setPenWidth(1);
        dc.fillRectangle(x + bodyW, batIconY + (batIconH * 0.28).toNumber(), 3, (batIconH * 0.44).toNumber());

        // Animated fill when charging, static fill otherwise
        var displayLevel = battery.toFloat();
        if (isCharging) {
            var frame = sec % 4;
            if (battery < 90) {
                displayLevel = battery.toFloat() + ((100.0 - battery.toFloat()) * frame / 3.0);
            } else {
                displayLevel = 25.0 * (frame + 1);
            }
        }

        var maxInnerW = batIconW - 9;
        var innerW = (maxInnerW * displayLevel / 100.0).toNumber();
        if (innerW > maxInnerW) {
            innerW = maxInnerW;
        }
        if (innerW > 0) {
            dc.fillRectangle(x + 3, batIconY + 3, innerW, batIconH - 6);
        }

        // Lightning bolt overlay while charging
        if (isCharging) {
            drawChargingBolt(dc, x + (bodyW / 2), cy, batIconH);
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

    private function drawChargingBolt(dc as Dc, cx as Number, cy as Number, h as Number) as Void {
        var halfH = (h / 2).toNumber() - 1;
        if (halfH < 4) {
            halfH = 4;
        }
        // Subtle black outline for contrast against the green fill
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(cx + 2, cy - halfH, cx - 2, cy);
        dc.drawLine(cx - 2, cy, cx + 2, cy);
        dc.drawLine(cx + 2, cy, cx - 2, cy + halfH);

        // Crisp white bolt
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx + 2, cy - halfH, cx - 2, cy);
        dc.drawLine(cx - 2, cy, cx + 2, cy);
        dc.drawLine(cx + 2, cy, cx - 2, cy + halfH);
        dc.setPenWidth(1);
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
