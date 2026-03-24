import { Node, Edge } from '../components/editor/SkillTreeCanvas';

export function buildGenericJSON(tiles: any, nodes: Record<string, Node>, edges: Edge[], projectName: string) {
  const getPrerequisites = (nodeId: string) => {
    return edges
      .filter(e => {
        const toNode = nodes[e.to];
        return toNode && toNode.id === nodeId;
      })
      .map(e => nodes[e.from]?.id)
      .filter(Boolean);
  };

  const safeParseJSON = (str?: string) => {
    if (!str) return {};
    try {
      return JSON.parse(str);
    } catch {
      return { raw: str };
    }
  };

  return {
    version: 1,
    projectName,
    exportedAt: new Date().toISOString(),
    tiles: Object.entries(tiles).map(([key, styleObj]) => {
      const style = styleObj as any;
      const [col, row] = key.split(',').map(Number);
      return { col, row, ...style };
    }),
    nodes: Object.entries(nodes).map(([key, node]) => {
      const [col, row] = key.split(',').map(Number);
      return {
        id: node.id,
        label: node.label,
        description: node.description || '',
        baseValue: node.baseValue || 0,
        buyValue: node.buyValue || 0,
        maxLevel: node.maxLevel || 1,
        icon: node.icon || '',
        imageUrl: node.imageUrl || '',
        state: node.state,
        shape: node.shape,
        color: node.color,
        col, row,
        prerequisites: getPrerequisites(node.id),
        onClickMeta: safeParseJSON(node.onClickMeta),
        hoverMeta: safeParseJSON(node.hoverMeta),
      };
    }),
    edges: edges.map(e => ({
      id: e.id,
      from: nodes[e.from]?.id,
      to: nodes[e.to]?.id,
      curveType: e.curveType || 'curved',
      style: e.style || 'solid',
      color: e.color || '#f59e0b',
      width: e.width || 2,
      directed: true,
    })),
  };
}
