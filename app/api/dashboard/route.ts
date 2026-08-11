import { NextResponse } from 'next/server';
import { DashboardService } from '@/services/dashboard-service';
import { demoRepository } from '@/services/demo-vault';

export function GET(): NextResponse {
  return NextResponse.json(new DashboardService(demoRepository()).snapshot());
}
