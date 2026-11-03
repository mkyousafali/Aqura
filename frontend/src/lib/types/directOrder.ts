export interface DirectOrder {
  id: string;
  template_id: string;
  order_number: number;
  quantity: number;
  branch_id: number | null;
  branch_name_en: string | null;
  branch_name_ar: string | null;
  product_code: string | null;
  barcode: string | null;
  product_name_en: string | null;
  created_at: string;
  updated_at: string;
  revision: number;
  has_photo: boolean;
  // Local inline image data returned by RPC, never an external Storage URL.
  photo_url?: string;
}

export interface DirectOrderTemplate {
  id: string;
  order_number: number;
  shop_name: string | null;
  shop_location: string | null;
  branch_id: number | null;
  branch_name_en: string | null;
  branch_name_ar: string | null;
  product_count: number;
  created_at: string;
}
