-- 011_duty_stations_demo.sql
-- Demo duty stations for the Civilian PCS application. The PCS origination/destination
-- picker (web.GetCivPCSLocationsByQuery) only surfaces zip-type warehouse.location rows
-- that have geography coordinates AND a matching crunch.gsaperdiem per-diem row; the base
-- seed provides only two (Fort Belvoir 22060, Fort Cavazos 76544), so the picker is nearly
-- empty. Add zip locations + coordinates + per-diem for the other seeded installations so
-- there are real from/to choices and ST_Distance can compute a mileage between them.
--
-- Idempotent: clears these demo rows (keyed by zip) first; warehouse.location.locationid
-- is GENERATED ALWAYS AS IDENTITY, so ids are assigned by the sequence. Coordinates are
-- geography SRID 4326 (lon lat), matching the existing rows so ST_Distance returns metres.
-- Real duty station data comes from the ETL.

DELETE FROM crunch.gsaperdiem
WHERE zipcode IN ('31905', '28310', '73503', '22202', '21005', '35898');
DELETE FROM warehouse.location
WHERE locationtype = 'zip'
  AND sourcesystemcode IN ('31905', '28310', '73503', '22202', '21005', '35898');

INSERT INTO warehouse.location
    (sourcesystemcode, locationtype, displayname, geometry, coordinates, amcosversionid)
VALUES
    ('31905', 'zip', 'Fort Moore, GA 31905',              NULL, ST_SetSRID(ST_MakePoint(-84.9527, 32.3529), 4326)::geography, 202501),
    ('28310', 'zip', 'Fort Liberty, NC 28310',            NULL, ST_SetSRID(ST_MakePoint(-78.9959, 35.1401), 4326)::geography, 202501),
    ('73503', 'zip', 'Fort Sill, OK 73503',               NULL, ST_SetSRID(ST_MakePoint(-98.4048, 34.6640), 4326)::geography, 202501),
    ('22202', 'zip', 'Pentagon, Arlington, VA 22202',     NULL, ST_SetSRID(ST_MakePoint(-77.0563, 38.8709), 4326)::geography, 202501),
    ('21005', 'zip', 'Aberdeen Proving Ground, MD 21005', NULL, ST_SetSRID(ST_MakePoint(-76.1319, 39.4670), 4326)::geography, 202501),
    ('35898', 'zip', 'Redstone Arsenal, AL 35898',        NULL, ST_SetSRID(ST_MakePoint(-86.6847, 34.6866), 4326)::geography, 202501);

-- Per-diem (FY2025 lodging / M&IE) keyed by zip + version; the picker requires a match.
INSERT INTO crunch.gsaperdiem
    (zipcode, fiscalyear, maximumlodgingrate, maximummealsandincidentalsrate, dateeffective, amcosversionid)
VALUES
    ('31905', 2025, 110, 68, '2024-10-01'::timestamp, 202501),
    ('28310', 2025, 110, 68, '2024-10-01'::timestamp, 202501),
    ('73503', 2025, 110, 68, '2024-10-01'::timestamp, 202501),
    ('22202', 2025, 258, 86, '2024-10-01'::timestamp, 202501),
    ('21005', 2025, 120, 74, '2024-10-01'::timestamp, 202501),
    ('35898', 2025, 115, 72, '2024-10-01'::timestamp, 202501);
