import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: Math.max(minWidth, weatherDashboard.implicitWidth + Appearance.padding.xl * 2)
    implicitHeight: weatherDashboard.implicitHeight + Appearance.padding.xl * 2

    readonly property int minWidth: 1080
    readonly property var today: Weather.forecast && Weather.forecast.length > 0 ? Weather.forecast[0] : null

    Component.onCompleted: Weather.reload()

    ColumnLayout {
        id: weatherDashboard

        anchors.centerIn: parent
        width: root.implicitWidth - Appearance.padding.xl * 2
        spacing: Appearance.spacing.lg

        // ── Header: city / date / sunrise & sunset ──
        RowLayout {
            Layout.fillWidth: true

            Column {
                Layout.alignment: Qt.AlignLeft
                spacing: 0

                StyledText {
                    text: Weather.error ? Weather.error : (Weather.city || qsTr("加载中..."))
                    font.pointSize: Appearance.font.size.headlineLarge
                    font.weight: 600
                    color: Weather.error ? Colours.palette.m3error : Colours.palette.m3onSurface
                }

                StyledText {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font.pointSize: Appearance.font.size.labelLarge
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Row {
                spacing: Appearance.spacing.xxl

                WeatherStat {
                    icon: "wb_twilight"
                    label: qsTr("日出")
                    value: Weather.cc ? Weather.cc.sunrise : "--:--"
                    colour: Colours.palette.m3tertiary
                }

                WeatherStat {
                    icon: "bedtime"
                    label: qsTr("日落")
                    value: Weather.cc ? Weather.cc.sunset : "--:--"
                    colour: Colours.palette.m3tertiary
                }
            }
        }

        // ── Current conditions (animated sky backdrop) ──
        StyledClippingRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainer

            WeatherBackground {
                anchors.fill: parent
                weatherCode: Weather.cc ? Number(Weather.cc.weatherCode) : -1
                iconName: Weather.icon
                windSpeedMs: (Weather.windSpeed ?? 0) / 3.6
                night: Weather.cc ? !(Weather.cc.isDay) : false
                rainBounceY: height
                scrollProgress: 0
                animate: Weather.error === ""
                fullCardParticleBounds: true
            }

            Row {
                anchors.centerIn: parent
                spacing: Appearance.spacing.xxl

                MaterialIcon {
                    text: Weather.icon
                    font.pointSize: Appearance.font.size.headlineLarge * 3.5
                    color: Colours.palette.m3secondary
                    animate: true
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: Weather.temp
                        font.pointSize: Appearance.font.size.headlineLarge * 2
                        font.weight: 700
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        text: Weather.description
                        font.pointSize: Appearance.font.size.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.sm

                    StyledText {
                        text: qsTr("体感 %1").arg(Weather.feelsLike)
                        font.pointSize: Appearance.font.size.labelLarge
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        text: Weather.cc ? qsTr("降水 %1 mm").arg(Weather.cc.precipitation ?? 0) : ""
                        font.pointSize: Appearance.font.size.labelLarge
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        // ── Detail cards: humidity / feels-like / wind / precip chance ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.lg

            DetailCard {
                icon: "water_drop"
                label: qsTr("湿度")
                value: Weather.humidity + "%"
                colour: Colours.palette.m3secondary
            }

            DetailCard {
                icon: "thermostat"
                label: qsTr("体感温度")
                value: Weather.feelsLike
                colour: Colours.palette.m3primary
            }

            DetailCard {
                icon: "air"
                label: qsTr("风")
                value: Weather.windSpeed ? Weather.windDirName + " " + Weather.beaufortText(Weather.windSpeed) : "--"
                colour: Colours.palette.m3tertiary
            }

            DetailCard {
                icon: "umbrella"
                label: qsTr("今日降水")
                value: root.today ? qsTr("%1% · %2 mm").arg(root.today.precipProb ?? 0).arg(root.today.precipSum ?? 0) : "--"
                colour: Colours.palette.m3secondary
            }
        }

        // ── Hourly: next 24h, time / icon / temp / precip chance ──
        StyledText {
            text: qsTr("24 小时预报")
            font.pointSize: Appearance.font.size.medium
            font.weight: 600
            color: Colours.palette.m3onSurface
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: hourlyRow.implicitHeight + Appearance.padding.md * 2
            radius: Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainer

            Flickable {
                id: hourlyFlick

                anchors.fill: parent
                contentWidth: hourlyRow.implicitWidth + Appearance.padding.md * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // Wheel-only: dragging here conflicts with the dashboard close gesture
                interactive: false

                Row {
                    id: hourlyRow

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.lg

                    Repeater {
                        model: Weather.hourly.length > 24 ? 24 : Weather.hourly.length

                        Item {
                            id: hourCard

                            required property int index

                            readonly property var hourData: Weather.hourly[index] ?? null

                            width: hourColumn.implicitWidth
                            height: hourColumn.implicitHeight

                            Column {
                                id: hourColumn

                                spacing: Appearance.spacing.xs

                                StyledText {
                                    text: hourCard.hourData?.hour ?? ""
                                    font.pointSize: Appearance.font.size.labelMedium
                                    color: Colours.palette.m3onSurfaceVariant
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                MaterialIcon {
                                    text: hourCard.hourData?.icon ?? "cloud_question"
                                    font.pointSize: Appearance.font.size.titleLarge
                                    color: Colours.palette.m3secondary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: Config.services.useFahrenheit ? (hourCard.hourData?.tempF ?? "--") + "°" : (hourCard.hourData?.tempC ?? "--") + "°"
                                    font.pointSize: Appearance.font.size.labelLarge
                                    font.weight: 600
                                    color: Colours.palette.m3onSurface
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2

                                    MaterialIcon {
                                        text: "water_drop"
                                        font.pointSize: Appearance.font.size.labelSmall
                                        color: hourCard.hourData && hourCard.hourData.precipProb >= 40 ? Colours.palette.m3primary : Colours.palette.m3outline
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: (hourCard.hourData?.precipProb ?? 0) + "%"
                                        font.pointSize: Appearance.font.size.labelSmall
                                        color: Colours.palette.m3onSurfaceVariant
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Wheel scroll, Calendar-style stepped scrolling. Drag stays with
            // the dashboard's tab/close gestures on purpose.
            CustomMouseArea {
                anchors.fill: parent

                function onWheel(event: WheelEvent): void {
                    const delta = (event.angleDelta.y || event.angleDelta.x) * 2;
                    hourlyFlick.contentX = Math.max(0, Math.min(hourlyFlick.contentWidth - hourlyFlick.width, hourlyFlick.contentX - delta));
                }
            }
        }

        // ── 16-day forecast, scrollable ──
        StyledText {
            text: qsTr("16 天预报")
            font.pointSize: Appearance.font.size.medium
            font.weight: 600
            color: Colours.palette.m3onSurface
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: forecastRow.implicitHeight + Appearance.padding.md * 2
            radius: Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainer

            Flickable {
                id: forecastFlick

                anchors.fill: parent
                contentWidth: forecastRow.implicitWidth + Appearance.padding.md * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: false

                Row {
                    id: forecastRow

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.lg

                    Repeater {
                        model: Weather.forecast

                        StyledRect {
                            id: dayCard

                            required property int index
                            required property var modelData

                            width: 110
                            height: 190
                            radius: Appearance.rounding.normal
                            color: index === 0 ? Colours.palette.m3secondaryContainer : "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: Appearance.spacing.sm

                                StyledText {
                                    text: dayCard.index === 0 ? qsTr("今天") : new Date(dayCard.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                                    font.pointSize: Appearance.font.size.medium
                                    font.weight: 600
                                    color: Colours.palette.m3primary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: new Date(dayCard.modelData.date).toLocaleDateString(Qt.locale(), "MMM d")
                                    font.pointSize: Appearance.font.size.labelLarge
                                    opacity: 0.7
                                    color: Colours.palette.m3onSurfaceVariant
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                MaterialIcon {
                                    text: dayCard.modelData.icon
                                    font.pointSize: Appearance.font.size.headlineLarge
                                    color: Colours.palette.m3secondary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2

                                    MaterialIcon {
                                        text: "umbrella"
                                        font.pointSize: Appearance.font.size.labelSmall
                                        color: dayCard.modelData.precipProb >= 40 ? Colours.palette.m3primary : Colours.palette.m3outline
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: (dayCard.modelData.precipProb ?? 0) + "%"
                                        font.pointSize: Appearance.font.size.labelSmall
                                        color: Colours.palette.m3onSurfaceVariant
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                StyledText {
                                    text: Config.services.useFahrenheit ? dayCard.modelData.maxTempF + "° / " + dayCard.modelData.minTempF + "°" : dayCard.modelData.maxTempC + "° / " + dayCard.modelData.minTempC + "°"
                                    font.weight: 600
                                    color: Colours.palette.m3tertiary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2

                                    MaterialIcon {
                                        text: "air"
                                        font.pointSize: Appearance.font.size.labelSmall
                                        color: Colours.palette.m3outline
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: Weather.beaufortText(dayCard.modelData.windMax ?? 0)
                                        font.pointSize: Appearance.font.size.labelSmall
                                        color: Colours.palette.m3onSurfaceVariant
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            CustomMouseArea {
                anchors.fill: parent

                function onWheel(event: WheelEvent): void {
                    const delta = (event.angleDelta.y || event.angleDelta.x) * 2;
                    forecastFlick.contentX = Math.max(0, Math.min(forecastFlick.contentWidth - forecastFlick.width, forecastFlick.contentX - delta));
                }
            }
        }
    }

    component DetailCard: StyledRect {
        id: detailRoot

        property string icon
        property string label
        property string value
        property color colour

        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: Appearance.rounding.small
        color: Colours.palette.m3surfaceContainer

        Row {
            anchors.centerIn: parent
            spacing: Appearance.spacing.lg

            MaterialIcon {
                text: icon
                color: colour
                font.pointSize: Appearance.font.size.titleMedium
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: detailRoot.label
                    font.pointSize: Appearance.font.size.labelMedium
                    color: Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    text: detailRoot.value
                    font.pointSize: Appearance.font.size.labelLarge
                    font.weight: 600
                    color: detailRoot.colour
                }
            }
        }
    }

    component WeatherStat: Row {
        id: statRoot

        property string icon
        property string label
        property string value
        property color colour

        spacing: Appearance.spacing.sm

        MaterialIcon {
            text: statRoot.icon
            color: statRoot.colour
            font.pointSize: Appearance.font.size.titleMedium
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: statRoot.value
                font.pointSize: Appearance.font.size.labelLarge
                font.weight: 600
                color: Colours.palette.m3onSurface
            }

            StyledText {
                text: statRoot.label
                font.pointSize: Appearance.font.size.labelMedium
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
