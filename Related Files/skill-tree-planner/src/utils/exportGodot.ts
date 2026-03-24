import JSZip from 'jszip';
import { buildGenericJSON } from './exportJson';

export async function buildGodotZip(tiles: any, nodes: any, edges: any, projectName: string) {
  const zip = new JSZip();
  const data = buildGenericJSON(tiles, nodes, edges, projectName);

  zip.file("skill_tree.json", JSON.stringify(data, null, 2));
  
  zip.file("skill_tree_loader.gd", `# skill_tree_loader.gd
# AutoLoad: Project > Project Settings > AutoLoad > Add this script as "SkillTreeLoader"
extends Node

var tree_data: Dictionary = {}
var node_states: Dictionary = {}

func _ready() -> void:
    load_tree("res://skill_tree.json")

func load_tree(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("SkillTreeLoader: Cannot open " + path)
        return
    var json = JSON.new()
    if json.parse(file.get_as_text()) != OK:
        push_error("SkillTreeLoader: JSON parse failed")
        return
    tree_data = json.get_data()
    for node in tree_data.get("nodes", []):
        node_states[node["id"]] = node["state"]
    print("SkillTreeLoader: Loaded %d nodes" % node_states.size())

func get_node_state(node_id: String) -> String:
    return node_states.get(node_id, "locked")

func can_unlock(node_id: String) -> bool:
    if get_node_state(node_id) == "unlocked":
        return false
    for node in tree_data.get("nodes", []):
        if node["id"] != node_id: continue
        for prereq in node.get("prerequisites", []):
            if get_node_state(prereq) != "unlocked":
                return false
        return true
    return false

func unlock(node_id: String) -> bool:
    if not can_unlock(node_id): return false
    node_states[node_id] = "unlocked"
    emit_signal("node_unlocked", node_id)
    return true

signal node_unlocked(node_id: String)
`);

  zip.file("README_godot.txt", `GODOT 4 SETUP
─────────────
1. Copy skill_tree.json into your Godot project's res:// folder
2. Copy skill_tree_loader.gd into your project
3. Go to: Project > Project Settings > AutoLoad
4. Click the folder icon, select skill_tree_loader.gd
5. Set Node Name to "SkillTreeLoader", click Add
6. Access anywhere in GDScript: SkillTreeLoader.unlock("node_id")`);

  return await zip.generateAsync({ type: "blob" });
}
