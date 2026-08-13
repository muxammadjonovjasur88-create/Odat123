// Simple LocalStorage Persistence Service for Territory Polygons and Run History

export interface TerritoryPolygon {
  id: string;
  ownerId: string;
  ownerName: string;
  ownerColor: string;
  points: Array<[number, number]>;
  capturedAt: string;
}

export class SimpleDBService {
  public getSavedPolygons(): TerritoryPolygon[] {
    try {
      const saved = localStorage.getItem('camera_vision_polygons');
      if (saved) return JSON.parse(saved);
    } catch (e) {
      console.warn('Error reading saved polygons:', e);
    }
    return [];
  }

  public savePolygons(polygons: TerritoryPolygon[]): void {
    try {
      localStorage.setItem('camera_vision_polygons', JSON.stringify(polygons));
    } catch (e) {
      console.error('Error saving polygons:', e);
    }
  }
}

export const db = new SimpleDBService();
