namespace PcbInspector {

public class DefectInfo : Object {
    public DefectType defect_type { get; set; }
    public double center_x { get; set; }
    public double center_y { get; set; }
    public double width { get; set; }
    public double height { get; set; }
    public double confidence { get; set; }

    public DefectInfo (
        DefectType defect_type,
        double center_x,
        double center_y,
        double width,
        double height,
        double confidence
    ) {
        this.defect_type = defect_type;
        this.center_x = center_x;
        this.center_y = center_y;
        this.width = width;
        this.height = height;
        this.confidence = confidence;
    }

    public Json.Node to_json_node () {
        var obj = new Json.Object ();
        obj.set_string_member ("type", defect_type.to_chinese ());
        obj.set_double_member ("confidence", confidence);
        obj.set_double_member ("center_x", center_x);
        obj.set_double_member ("center_y", center_y);
        obj.set_double_member ("width", width);
        obj.set_double_member ("height", height);
        var node = new Json.Node (Json.NodeType.OBJECT);
        node.set_object (obj);
        return node;
    }

    public static DefectInfo from_json_object (Json.Object obj) {
        string type_text = obj.get_string_member ("type");
        return new DefectInfo (
            defect_type_from_text (type_text),
            obj.has_member ("center_x") ? obj.get_double_member ("center_x") : 0.5,
            obj.has_member ("center_y") ? obj.get_double_member ("center_y") : 0.5,
            obj.has_member ("width") ? obj.get_double_member ("width") : 0.1,
            obj.has_member ("height") ? obj.get_double_member ("height") : 0.1,
            obj.has_member ("confidence") ? obj.get_double_member ("confidence") : 0.0
        );
    }

    private static DefectType defect_type_from_text (string text) {
        switch (text) {
            case "鼠咬":
            case "Mouse_bite":
                return DefectType.MOUSE_BITE;
            case "开路":
            case "Open_circuit":
                return DefectType.OPEN_CIRCUIT;
            case "短路":
            case "Short":
                return DefectType.SHORT;
            case "毛刺":
            case "Spur":
                return DefectType.SPUR;
            case "残铜":
            case "Spurious_copper":
                return DefectType.SPURIOUS_COPPER;
            default:
                return DefectType.MOUSE_BITE;
        }
    }
}

}
