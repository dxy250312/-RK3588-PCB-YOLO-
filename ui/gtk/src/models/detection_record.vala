namespace PcbInspector {

public class DetectionRecord : Object {
    public string record_id { get; set; default = ""; }
    public string timestamp { get; set; default = ""; }
    public string original_image_path { get; set; default = ""; }
    public string annotated_image_path { get; set; default = ""; }
    public bool has_defect { get; set; default = false; }
    public List<DefectInfo> defects { get; private set; }

    public int total_defect_count {
        get { return (int) defects.length (); }
    }

    public DetectionRecord () {
        defects = new List<DefectInfo> ();
        timestamp = new DateTime.now_local ().format ("%Y-%m-%d %H:%M:%S");
        record_id = "PCB-" + new DateTime.now_local ().format ("%Y%m%d-%H%M%S");
    }

    public void add_defect (DefectInfo defect) {
        defects.append (defect);
        has_defect = true;
    }

    public int get_defect_count (DefectType type) {
        int count = 0;
        foreach (var defect in defects) {
            if (defect.defect_type == type) {
                count++;
            }
        }
        return count;
    }

    public Json.Node to_json_node () {
        var obj = new Json.Object ();
        obj.set_string_member ("record_id", record_id);
        obj.set_string_member ("timestamp", timestamp);
        obj.set_string_member ("original_image", original_image_path);
        obj.set_string_member ("annotated_image", annotated_image_path);
        obj.set_boolean_member ("has_defect", has_defect);
        obj.set_int_member ("total_defects", total_defect_count);

        var counts = new Json.Object ();
        counts.set_int_member ("鼠咬", get_defect_count (DefectType.MOUSE_BITE));
        counts.set_int_member ("开路", get_defect_count (DefectType.OPEN_CIRCUIT));
        counts.set_int_member ("短路", get_defect_count (DefectType.SHORT));
        counts.set_int_member ("毛刺", get_defect_count (DefectType.SPUR));
        counts.set_int_member ("残铜", get_defect_count (DefectType.SPURIOUS_COPPER));
        obj.set_object_member ("defect_counts", counts);

        var arr = new Json.Array ();
        foreach (var defect in defects) {
            arr.add_element (defect.to_json_node ());
        }
        obj.set_array_member ("defects", arr);

        var node = new Json.Node (Json.NodeType.OBJECT);
        node.set_object (obj);
        return node;
    }

    public static DetectionRecord from_json_node (Json.Node node) {
        var record = new DetectionRecord ();
        var obj = node.get_object ();
        if (obj == null) {
            return record;
        }

        record.record_id = get_string (obj, "record_id", record.record_id);
        record.timestamp = get_string (obj, "timestamp", record.timestamp);
        record.original_image_path = get_string (obj, "original_image", "");
        record.annotated_image_path = get_string (obj, "annotated_image", "");
        record.has_defect = obj.has_member ("has_defect") && obj.get_boolean_member ("has_defect");

        if (obj.has_member ("defects")) {
            var arr = obj.get_array_member ("defects");
            if (arr != null) {
                for (uint i = 0; i < arr.get_length (); i++) {
                    var item = arr.get_object_element (i);
                    if (item != null) {
                        record.add_defect (DefectInfo.from_json_object (item));
                    }
                }
            }
        }
        record.has_defect = record.defects.length () > 0 || record.has_defect;
        return record;
    }

    private static string get_string (Json.Object obj, string key, string fallback) {
        return obj.has_member (key) ? obj.get_string_member (key) : fallback;
    }
}

}
