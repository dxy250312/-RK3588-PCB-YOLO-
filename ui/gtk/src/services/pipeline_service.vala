namespace PcbInspector {

public class PipelineService : Object {
    public signal void result_received (DetectionRecord record, string image_path);

    public void publish_result (DetectionRecord record, string image_path) {
        result_received (record, image_path);
    }
}

}
