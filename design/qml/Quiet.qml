// Secondary text that reads as a remark ("three bills left this month"): body sans, muted.
import QtQuick

Text {
    color: Theme.textMuted
    font.family: Theme.typeFamilySans
    font.pixelSize: Theme.typeSizeBody
    font.weight: Theme.typeWeightBody
    font.features: { "tnum": 1, "lnum": 1 }
    verticalAlignment: Text.AlignVCenter
}
