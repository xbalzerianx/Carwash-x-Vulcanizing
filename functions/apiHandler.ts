import { createClientFromRequest } from 'npm:@base44/sdk@0.8.25';

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS, PATCH',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-base44-app-id',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const base44 = createClientFromRequest(req);
    const url = new URL(req.url);
    const path = url.pathname.split('/').filter(Boolean);
    const body = await req.json().catch(() => ({}));
    const { action, entity, data, query, id } = body;

    // Generic entity CRUD
    const entityMap: Record<string, any> = {
      Employee: base44.asServiceRole.entities.Employee,
      Service: base44.asServiceRole.entities.Service,
      CarWash: base44.asServiceRole.entities.CarWash,
      RewardCampaign: base44.asServiceRole.entities.RewardCampaign,
    };

    if (!entity || !entityMap[entity]) {
      return Response.json({ error: 'Unknown entity' }, { status: 400, headers: corsHeaders });
    }

    const ent = entityMap[entity];
    let result;

    switch (action) {
      case 'list':
        result = await ent.list();
        break;
      case 'filter':
        result = await ent.filter(query || {});
        break;
      case 'get':
        result = await ent.get(id);
        break;
      case 'create':
        result = await ent.create(data);
        break;
      case 'update':
        result = await ent.update(id, data);
        break;
      case 'delete':
        result = await ent.delete(id);
        break;
      default:
        return Response.json({ error: 'Unknown action' }, { status: 400, headers: corsHeaders });
    }

    return Response.json({ ok: true, data: result }, { headers: corsHeaders });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500, headers: { 'Access-Control-Allow-Origin': '*' } });
  }
});
