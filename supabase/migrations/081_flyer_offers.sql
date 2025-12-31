-- Flyer Offers Table Schema
CREATE TABLE IF NOT EXISTS flyer_offers (
  id INTEGER PRIMARY KEY DEFAULT nextval('flyer_offers_id_seq'),
  flyer_id INTEGER NOT NULL,
  offer_id INTEGER NOT NULL,
  position_on_flyer INTEGER,
  highlight BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
