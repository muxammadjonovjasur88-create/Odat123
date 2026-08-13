import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import { TerritoryPolygon, UserProfile } from '../../types';

interface TerritoryMapViewProps {
  user: UserProfile;
  currentPos: [number, number];
  path: Array<[number, number]>;
  polygons: TerritoryPolygon[];
  notification?: string | null;
}

export const TerritoryMapView: React.FC<TerritoryMapViewProps> = ({
  user,
  currentPos,
  path,
  polygons,
  notification,
}) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const polylineRef = useRef<L.Polyline | null>(null);
  const userMarkerRef = useRef<L.CircleMarker | null>(null);
  const polygonLayersRef = useRef<Map<string, L.Polygon>>(new Map());

  // Initialize Leaflet Map
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: currentPos,
      zoom: 17,
      zoomControl: false,
      attributionControl: false,
    });

    // Dark tile layer (CartoDB Dark Matter)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      maxZoom: 19,
      subdomains: 'abcd',
    }).addTo(map);

    // Glowing Neon Cyan Path Polyline
    const polyline = L.polyline([], {
      color: '#00F3FF',
      weight: 6,
      opacity: 0.9,
      lineCap: 'round',
      lineJoin: 'round',
    }).addTo(map);
    polylineRef.current = polyline;

    // Pulse User Location Marker
    const userMarker = L.circleMarker(currentPos, {
      radius: 10,
      fillColor: '#00F3FF',
      color: '#FFFFFF',
      weight: 3,
      opacity: 1,
      fillOpacity: 0.95,
    }).addTo(map);
    userMarkerRef.current = userMarker;

    mapRef.current = map;

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // Update Map Position, User Marker, and Path Line
  useEffect(() => {
    if (!mapRef.current) return;

    // Pan map smoothly to current GPS location
    mapRef.current.panTo(currentPos, { animate: true, duration: 0.5 });

    if (userMarkerRef.current) {
      userMarkerRef.current.setLatLng(currentPos);
    }

    if (polylineRef.current && path.length > 0) {
      polylineRef.current.setLatLngs(path);
    }
  }, [currentPos, path]);

  // Render Closed Polygon Territories
  useEffect(() => {
    if (!mapRef.current) return;
    const map = mapRef.current;

    polygons.forEach(poly => {
      if (!polygonLayersRef.current.has(poly.id)) {
        const polygonLayer = L.polygon(poly.points, {
          color: poly.ownerColor,
          fillColor: poly.ownerColor,
          fillOpacity: 0.45,
          weight: 3,
        }).addTo(map);

        polygonLayer.bindPopup(`
          <div style="font-family: sans-serif; padding: 4px; text-align: center;">
            <b style="color: ${poly.ownerColor};">${poly.ownerName}</b><br/>
            <span style="font-size: 11px; color: #aaa;">Egallangan Hudud</span>
          </div>
        `);

        polygonLayersRef.current.set(poly.id, polygonLayer);
      }
    });
  }, [polygons]);

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      {/* Map Container */}
      <div ref={mapContainerRef} style={{ width: '100%', height: '100%', minHeight: '350px', backgroundColor: '#0b0f19' }} />

      {/* Closed Loop / Alert Banner */}
      {notification && (
        <div
          style={{
            position: 'absolute',
            top: '16px',
            left: '50%',
            transform: 'translateX(-50%)',
            backgroundColor: 'rgba(10, 15, 25, 0.95)',
            border: '2px solid #39FF14',
            boxShadow: '0 0 24px rgba(57, 255, 20, 0.6)',
            color: '#39FF14',
            padding: '10px 20px',
            borderRadius: '24px',
            fontWeight: 800,
            fontSize: '0.85rem',
            letterSpacing: '0.5px',
            zIndex: 1000,
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            pointerEvents: 'none',
            textAlign: 'center',
          }}
        >
          {notification}
        </div>
      )}
    </div>
  );
};
