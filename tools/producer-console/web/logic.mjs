// Pure workbench operations. Inputs are read from the project's CSV files.
export function calculatePreview(c, p) {
  const anchor = c.planet * p.anchor_planet_contribution + c.system * p.anchor_system_contribution + c.cosmic * p.anchor_cosmic_contribution;
  const a = Math.max(0, Math.min(p.awakening_before_final_cap, p.initial_awakening + Math.min(c.insight, p.insight_cap) + anchor - c.wounds));
  const upkeep = c.planet * p.anchor_planet_upkeep + c.system * p.anchor_system_upkeep + c.cosmic * p.anchor_cosmic_upkeep;
  const whispers = Math.min(p.whisper_cap, p.whisper_base + Math.floor(a / p.whisper_growth_step));
  const income = Math.floor(Math.min(p.cult_income_cap, Math.sqrt(c.population)) * c.cohesion / 100);
  return {a, anchor, upkeep, whispers, income, qualified: a >= p.manifest_requirement && c.cosmic > 0 && c.system > 0};
}

export function validateFeedback(value, targetExists) {
  if (!value || value.schemaVersion !== 1 || !Number.isInteger(value.revision) || value.revision < 0 || !Array.isArray(value.items) || value.items.length > 1000) throw new Error('不是有效的讨论备份。');
  const fields = {id:80, target:160, title:160, body:12000, createdAt:80, updatedAt:80, sourceRevision:80};
  const allowed = new Set([...Object.keys(fields), 'kind', 'status']);
  const ids = new Set();
  for (const item of value.items) {
    if (!item || typeof item !== 'object' || Object.keys(item).some(k => !allowed.has(k))) throw new Error('讨论项包含未知字段。');
    for (const [field, length] of Object.entries(fields)) {
      if (typeof item[field] !== 'string' || !item[field].trim() || [...item[field]].length > length) throw new Error('讨论项缺失或过长：' + field);
    }
    if (ids.has(item.id)) throw new Error('备份中有重复讨论编号：' + item.id);
    ids.add(item.id);
    if (!targetExists(item.target)) throw new Error('包含未知讨论目标：' + item.target);
    if (!['question', 'change', 'concern'].includes(item.kind) || !['open', 'answered', 'planned', 'archived'].includes(item.status)) throw new Error('讨论类型或状态不正确。');
  }
  return value;
}

export function mergeFeedback(current, incoming) {
  const merged = [...current];
  for (const item of incoming) {
    const old = merged.find(n => n.id === item.id);
    if (old) {
      if (Object.keys({...old, ...item}).some(k => old[k] !== item[k])) throw new Error(`编号 ${item.id} 内容冲突；请先合并，现有讨论未覆盖。`);
    } else merged.push(item);
  }
  return merged;
}

// Traceability facts are computed by the repository tracker, never by discussion
// status. These helpers only locate and filter the read-only result.
export const deliveryGroups = ['requirements', 'contracts', 'tasks', 'scenarios'];

export function deliveryItem(delivery, id) {
  for (const group of deliveryGroups) {
    const item = (delivery?.[group] || []).find(entry => entry.id === id);
    if (item) return {...item, group};
  }
  return null;
}

export function deliveryStatus(item) {
  if (item.group === 'requirements') return item.coverage?.verification || 'unverified';
  if (item.group === 'scenarios') return item.verification?.status || 'unverified';
  if (item.group === 'tasks') {
    if (item.status === 'verified' && item.verification && item.verification !== 'passed') return item.verification;
    return item.status || 'planned';
  }
  return 'contract';
}

export function filterDelivery(delivery, {group = 'requirements', feature = 'all', status = 'all', query = ''} = {}) {
  const text = query.trim().toLowerCase();
  return (delivery?.[group] || []).map(item => ({...item, group})).filter(item => {
    if (feature !== 'all' && !item.features?.includes(feature)) return false;
    if (status === 'gaps') {
      if (group === 'requirements' && item.coverage?.assigned && item.coverage?.implemented && item.coverage?.verification === 'passed') return false;
      if (group === 'tasks' && deliveryStatus(item) === 'verified' && item.readiness?.ready !== false) return false;
      if (group === 'scenarios' && item.verification?.status === 'passed') return false;
    } else if (status !== 'all' && deliveryStatus(item) !== status) return false;
    return !text || JSON.stringify(item).toLowerCase().includes(text);
  });
}

export function deliveryConnections(delivery, item) {
  const result = new Set([...(item.tasks || []), ...(item.contracts || []), ...(item.acceptance || []), ...(item.dependsOn || [])]);
  for (const group of deliveryGroups) for (const other of delivery?.[group] || []) {
    if ([...(other.tasks || []), ...(other.contracts || []), ...(other.acceptance || []), ...(other.dependsOn || [])].includes(item.id)) result.add(other.id);
  }
  result.delete(item.id);
  return [...result];
}

export function deliveryContext(delivery, item, statusLabel = value => value) {
  const labels = {requirements:'关键行为', contracts:'结算约定', tasks:'开发任务', scenarios:'验收场景'};
  const listed = values => values?.length ? values.map(value => '- ' + value).join('\n') : '- 尚未登记';
  const sections = [
    `追踪类别：${labels[item.group]}`,
    `当前状态：${statusLabel(deliveryStatus(item))}`,
    `关联：${deliveryConnections(delivery, item).join('、') || '无'}`,
  ];
  if (item.group === 'scenarios') {
    sections.push(`给定局势：${item.given || '尚未登记'}`, `执行操作：${item.when || '尚未登记'}`,
      `预期后果：\n${listed(item.then)}`);
    const evidence = item.verification?.evidence?.length ? item.verification.evidence : item.evidence || [];
    sections.push('验收证据：\n' + (evidence.length ? evidence.map(record => {
      const lines = [`- ${record.check} · ${statusLabel(record.status || 'unverified')} · ${record.report}`];
      if (record.generatedAt) lines.push(`  运行时间：${record.generatedAt}`);
      if (record.reason) lines.push(`  判定说明：${record.reason}`);
      if (record.changed?.length) lines.push(`  已变化来源：${record.changed.join('、')}`);
      return lines.join('\n');
    }).join('\n') : '- 尚未记录可用运行证据；场景已定义不表示通过。'));
  } else if (item.group === 'tasks') {
    sections.push(`任务登记：${statusLabel(item.status)}`,
      `当前验收：${statusLabel(item.verification || 'unverified')}`,
      `交付范围：${item.scope || '尚未登记'}`,
      `前置任务：\n${listed(item.dependsOn)}`,
      `开工条件：${item.readiness?.ready ? '已登记前置已满足，仍需读取当前规则。' : '前置尚未满足或未核对。'}`,
      `阻塞项：\n${item.readiness?.blockedBy?.length ? listed(item.readiness.blockedBy) : '- 无已登记阻塞项'}`,
      `交付物：\n${listed(item.deliverables)}`,
      `验收场景：\n${listed(item.acceptance)}`);
  } else if (item.group === 'contracts') {
    sections.push(`结算责任：${item.owner || '尚未登记'}`,
      `生效时点：${item.phase || '尚未登记'}`,
      `读取事实：\n${listed(item.reads)}`, `写入事实：\n${listed(item.writes)}`,
      `成立前提：\n${listed(item.preconditions)}`,
      `冲突与结算顺序：\n${listed(item.resolution)}`,
      `必须保持的条件：\n${listed(item.invariants)}`,
      `验收场景：\n${listed(item.acceptance)}`);
  } else {
    sections.push(`规则：${item.rule || '尚未登记'}`, `开发任务：\n${listed(item.tasks)}`,
      `结算约定：\n${listed(item.contracts)}`, `验收场景：\n${listed(item.acceptance)}`,
      `当前缺口：\n${item.coverage?.missing?.length ? listed(item.coverage.missing) : '- 已登记链路无缺口；不推定未登记行为已覆盖。'}`);
  }
  return sections.join('\n\n');
}
