import dotenv from "dotenv";

dotenv.config({ path: '../.env' });

async function inspectSchema() {
    const url = `${process.env.SUPABASE_URL}/rest/v1/`;
    const response = await fetch(url, {
        headers: {
            'apikey': process.env.SUPABASE_SERVICE_ROLE_KEY,
            'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`
        }
    });
    
    if (!response.ok) {
        console.error("Failed to fetch schema:", response.statusText);
        process.exit(1);
    }
    
    const schema = await response.json();
    console.log("Paths available in Supabase REST API:");
    Object.keys(schema.paths).forEach(path => {
        console.log(path);
    });
}

inspectSchema();
