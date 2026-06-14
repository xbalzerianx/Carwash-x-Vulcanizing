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
    const body = await req.json().catch(() => ({}));
    const { action, entity, data, query, id } = body;

    // ── Special action: upload avatar base64 → public CDN URL ──
    if (action === 'uploadAvatar') {
      const { base64, employeeId } = body;
      if (!base64) return Response.json({ error: 'No base64 provided' }, { status: 400, headers: corsHeaders });

      // Strip data URL prefix → raw base64 bytes
      const matches = base64.match(/^data:([A-Za-z-+/]+);base64,(.+)$/);
      if (!matches) return Response.json({ error: 'Invalid base64 format' }, { status: 400, headers: corsHeaders });
      const mimeType = matches[1];
      const rawBase64 = matches[2];
      const bytes = Uint8Array.from(atob(rawBase64), c => c.charCodeAt(0));

      // Upload to Base44 public storage
      const ext = mimeType.includes('png') ? 'png' : 'jpg';
      const fileName = `avatar_${employeeId || Date.now()}.${ext}`;
      const fileUrl = await base44.files.upload(new File([bytes], fileName, { type: mimeType }));

      return Response.json({ ok: true, data: { url: fileUrl } }, { headers: corsHeaders });
    }

    const entityMap: Record<string, any> = {
      Employee:         base44.asServiceRole.entities.Employee,
      Service:          base44.asServiceRole.entities.Service,
      CarWash:          base44.asServiceRole.entities.CarWash,
      RewardCampaign:   base44.asServiceRole.entities.RewardCampaign,
      CommissionPayout: base44.asServiceRole.entities.CommissionPayout,
      ActivityLog:      base44.asServiceRole.entities.ActivityLog,
      VulcanizingProduct: base44.asServiceRole.entities.VulcanizingProduct,
      VulcanizingJob:     base44.asServiceRole.entities.VulcanizingJob,
    };

    if (!entity || !entityMap[entity]) {
      return Response.json({ error: 'Unknown entity: ' + entity }, { status: 400, headers: corsHeaders });
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
        return Response.json({ error: 'Unknown action: ' + action }, { status: 400, headers: corsHeaders });
    }

    return Response.json({ ok: true, data: result }, { headers: corsHeaders });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500, headers: { 'Access-Control-Allow-Origin': '*' } });
  }
});
