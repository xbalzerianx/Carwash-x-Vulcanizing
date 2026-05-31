import { createClientFromRequest } from 'npm:@base44/sdk@0.8.25';

Deno.serve(async (req) => {
  try {
    const base44 = createClientFromRequest(req);
    const user = await base44.auth.me();
    if (!user) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await req.json().catch(() => ({}));
    const { startDate, endDate, reportType } = body;

    // Fetch all car washes within date range
    const allWashes = await base44.asServiceRole.entities.CarWash.list();
    
    const filtered = allWashes.filter((w: any) => {
      const date = w.transaction_date || w.created_date;
      return date >= startDate && date <= endDate;
    });

    // Group by employee
    const byEmployee: Record<string, any> = {};
    for (const wash of filtered) {
      const empId = wash.employee_id;
      if (!byEmployee[empId]) {
        byEmployee[empId] = {
          employee_id: empId,
          employee_name: wash.employee_name || 'Unknown',
          cars_washed: 0,
          total_sales: 0,
          total_commission: 0,
        };
      }
      byEmployee[empId].cars_washed += 1;
      byEmployee[empId].total_sales += wash.total_amount || 0;
      byEmployee[empId].total_commission += wash.commission_amount || 0;
    }

    const summary = Object.values(byEmployee).sort((a: any, b: any) => {
      if (b.cars_washed !== a.cars_washed) return b.cars_washed - a.cars_washed;
      return b.total_sales - a.total_sales;
    });

    const totalRevenue = filtered.reduce((s: number, w: any) => s + (w.total_amount || 0), 0);
    const totalCars = filtered.length;
    const totalCommission = filtered.reduce((s: number, w: any) => s + (w.commission_amount || 0), 0);

    return Response.json({
      ok: true,
      report: {
        startDate,
        endDate,
        reportType,
        totalRevenue,
        totalCars,
        totalCommission,
        averageSale: totalCars > 0 ? totalRevenue / totalCars : 0,
        employeeSummary: summary,
        transactions: filtered,
      }
    });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
});
