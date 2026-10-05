import QtQuick
import qs.Commons
import qs.Bar
import qs.Services

// The theme picker's "From wallpaper" card: the picture itself, the bar and a
// panel in the colours it gives (WallMock), and a badge saying where they come
// from. Before the feature's first use there is no such theme yet: the card
// then previews the wallpaper on screen, and Enter makes the theme from it.
Item {
    id: card
    required property var theme          // the catalogue entry, or { virtual: true }
    readonly property bool virtual: !!theme.virtual
    readonly property string picture: !virtual && theme.backgrounds && theme.backgrounds.length ? theme.backgrounds[0] : Wallpaper.file
    readonly property var colors: !virtual ? theme.colors
        : (WallTheme.preview && WallTheme.previewPath === Wallpaper.file ? WallTheme.preview.colors : null)

    Image {
        anchors.fill: parent
        source: card.picture ? "file://" + card.picture : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(1024, 640)
        cache: true
    }
    WallMock { anchors.fill: parent; colors: card.colors }

    // where the colours come from
    Rectangle {
        readonly property real k: card.width / 768
        x: 12 * k; anchors.bottom: parent.bottom; anchors.bottomMargin: 12 * k
        width: badge.width + 20 * k; height: 30 * k
        radius: height / 2
        color: card.colors ? card.colors.bg0 : Theme.c.bg0
        border.width: 1; border.color: card.colors ? card.colors.bg3 : Theme.c.border
        Row {
            id: badge
            anchors.centerIn: parent
            spacing: 7 * parent.k
            Icon { anchors.verticalCenter: parent.verticalCenter; icon: "palette"; size: 14 * parent.parent.k
                   color: card.colors ? card.colors.accent_bright : Theme.c.accentBright }
            Label { anchors.verticalCenter: parent.verticalCenter
                    text: card.virtual ? "From your wallpaper · Enter to try it" : "From your wallpaper"
                    font.pixelSize: 11 * parent.parent.k; color: card.colors ? card.colors.fg : Theme.c.fg }
        }
    }
}
