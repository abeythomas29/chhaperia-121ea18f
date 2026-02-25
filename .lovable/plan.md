

# Chhaperia Cables — Production Tracking Tool

A web-based production tracking system for Chhaperia Cables with two panels: **Admin** and **Worker**, both accessible via browser. Uses **Supabase** for database, authentication, and API.

---

## 1. Login & Authentication
- Single login page branded with "Chhaperia Cables" logo and name
- Username/Employee ID + password authentication via Supabase Auth
- Role-based redirect: Admins → Admin Dashboard, Workers → Worker Panel
- Three roles: **Super Admin**, **Admin**, **Worker** (stored in a separate `user_roles` table)

## 2. Database Structure (Supabase)
- **profiles** — name, employee_id, username, status (linked to auth.users)
- **user_roles** — role assignment (super_admin, admin, worker)
- **product_categories** — category name (e.g., "Semiconductor Woven Water Blocking Tape"), status
- **product_codes** — code (e.g., CHSCWWBT 18, 20, 22, 25), linked to category, status
- **company_clients** — client/customer name, status
- **production_entries** — product_code, date, worker, rolls_count, quantity_per_roll, total_quantity, issued_to_company, unit (meters/kg)
- Row-Level Security on all tables

## 3. Admin Panel (Web)
### Dashboard
- Overview stats: total production entries today/this week/this month
- Production volume chart (daily/weekly trends using Recharts)
- Top products and top clients summary cards

### Production Logs
- Searchable, filterable table of all production entries
- Filter by date range, product code, worker, client
- Export capability (CSV)

### Product Management
- View/add/edit product categories
- View/add/edit product codes within categories
- Activate/deactivate products

### Client Management
- View/add/edit clients/customers
- Activate/deactivate clients

### User Management (Super Admin only)
- View all workers and admins
- Add new workers/admins with employee ID & credentials
- Activate/deactivate users
- Assign roles

## 4. Worker Panel (Web)
### Production Entry Form
- Select date (defaults to today)
- Select product code from dropdown (with search)
- **Add new product code** option if not listed — worker can create a new code on the fly
- Select client/customer from dropdown (with search)
- **Add new client** option if not listed — worker can create a new client on the fly
- Enter: number of rolls, quantity per roll, unit
- Auto-calculated total quantity
- Submit entry with confirmation

### My Production History
- List of own entries with date, product, client, quantity
- Filter by date range

## 5. Design & Branding
- Orange and dark blue color scheme (matching Chhaperia brand)
- Clean, professional industrial look
- Responsive design — works on desktop and mobile browsers
- Sidebar navigation for admin, simplified nav for workers

## 6. Key Features
- Workers can add new product codes and new clients directly from the entry form
- All data stored in Supabase with proper RLS policies
- Role-based access control throughout
- Real-time data — admin sees worker entries as they're submitted

