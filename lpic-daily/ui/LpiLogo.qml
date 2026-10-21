import QtQuick
import QtQuick.Shapes

// LPI's official monochrome symbol (Simple Icons), recoloured by Serpantinum.
Item {
    id: root
    property color tint: "#cba6f7"

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: Math.min(root.width, root.height) / 24
        // Render the vector at 4x resolution before downscaling to Bar size.
        layer.enabled: true
        layer.textureSize: Qt.size(96, 96)
        layer.smooth: true
        layer.mipmap: true

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.tint
            PathSvg {
                path: "M12-.0002c-6.6273 0-12 5.3728-12 11.9997 0 6.627 5.3727 12 12.0007 12.0007s12-5.3728 12-12.0007S18.627-.0002 12-.0002Zm0 20.987c-4.9632 0-8.987-4.0231-8.987-8.9866 0-4.9635 4.0238-8.9867 8.987-8.9867 4.9632 0 8.987 4.0235 8.987 8.9867 0 4.9631-4.0238 8.9867-8.987 8.9867zm5.1043-3.0031.7995-2.9975h-7.1631L13.5062 4.495h-2.9978L6.9118 17.9837Zm.2896-10.4938c0 .8225-.6697 1.4938-1.4938 1.4938s-1.4897-.6716-1.4897-1.4938c0-.8223.6675-1.4907 1.4897-1.4907s1.4938.6688 1.4938 1.4907"
            }
        }
    }

    Behavior on tint { ColorAnimation { duration: 220 } }
}
