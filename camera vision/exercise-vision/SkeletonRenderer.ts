// ODAT — Visual Skeleton Overlay Renderer (Disabled - No Visual Overlay)

import { PoseLandmarks, DetailedBodyChecklist } from './types';

export function drawDetailedVectorSkeleton(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  _landmarks: PoseLandmarks | null,
  _checklist?: DetailedBodyChecklist
): void {
  // Completely clear canvas — No visual skeleton, lines, or dots are drawn over video feed
  ctx.clearRect(0, 0, w, h);
}
