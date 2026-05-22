#!/bin/bash
set -e

echo "🔥⚓ Setting up Interactive KumoRFM Live Demo..."

# 1. Handle .env
if [ ! -f .env ]; then
    echo "KUMO_API_KEY=" > .env
    echo "✅ Created .env file"
fi

if ! grep -q "KUMO_API_KEY=" .env || grep -q "KUMO_API_KEY=$" .env || grep -q "KUMO_API_KEY=your_key_here" .env; then
    echo ""
    echo "⚠️  Please add your KUMO_API_KEY to the .env file"
    echo "   Get a free key at: https://kumorfm.ai"
    echo ""
    read -p "Press Enter after you've added the key to .env..."
fi

# 2. Install dependencies
echo "📦 Installing dependencies..."
pip install -q kumoai streamlit pandas plotly networkx pyvis python-dotenv

# 3. Create the interactive demo
echo "🚀 Creating kumo_rfm_live_demo.py ..."

cat > kumo_rfm_live_demo.py << 'PYTHON_EOF'
import os
import pandas as pd
import streamlit as st
from dotenv import load_dotenv
import kumoai.experimental.rfm as rfm
import networkx as nx
from pyvis.network import Network
import tempfile

load_dotenv()
st.set_page_config(page_title="KumoRFM Live Demo", layout="wide")
st.title("🚀 KumoRFM Live Interactive Demo")
st.caption("Real multi-table relational predictions powered by KumoRFM (live API)")

# ==================== DATA ====================
@st.cache_data
def get_data():
    customers = pd.DataFrame({
        "customer_id": [1,2,3,4,5,6,7,8],
        "age": [22,45,31,52,23,40,36,28],
        "country": ["US","US","CA","DE","FR","US","JP","CA"],
    })

    orders = pd.DataFrame({
        "order_id": [101,102,103,104,105,106,107,108,109],
        "customer_id": [1,1,2,3,4,5,6,7,8],
        "product_id": [201,202,203,204,205,206,207,208,209],
        "amount": [120,340,900,1500,80,620,710,230,400],
        "order_date": pd.to_datetime(["2025-01-10","2025-02-15","2025-01-20","2025-03-01",
                                      "2025-02-10","2025-01-05","2025-03-12","2025-02-28","2025-03-05"])
    })

    products = pd.DataFrame({
        "product_id": [201,202,203,204,205,206,207,208,209],
        "category": ["A","B","A","C","B","A","C","B","A"]
    })

    events = pd.DataFrame({
        "event_id": list(range(1,11)),
        "customer_id": [1,1,2,3,4,5,6,7,8,8],
        "event_type": ["view","buy","view","view","buy","view","buy","view","buy","view"],
        "event_time": pd.to_datetime(["2025-01-09","2025-01-10","2025-01-18","2025-02-28",
                                      "2025-02-09","2025-01-04","2025-03-10","2025-02-25","2025-03-04","2025-03-06"])
    })
    return customers, orders, products, events

customers, orders, products, events = get_data()

with st.expander("📊 Data Tables", expanded=False):
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Customers"); st.dataframe(customers, hide_index=True, use_container_width=True)
        st.subheader("Products"); st.dataframe(products, hide_index=True, use_container_width=True)
    with col2:
        st.subheader("Orders"); st.dataframe(orders, hide_index=True, use_container_width=True)
        st.subheader("Events"); st.dataframe(events, hide_index=True, use_container_width=True)

# ==================== KUMO INITIALIZATION ====================
st.divider()
st.subheader("🔌 KumoRFM Connection")

if "kumo_model" not in st.session_state:
    if st.button("🚀 Initialize KumoRFM & Build Relational Graph", type="primary"):
        api_key = os.getenv("KUMO_API_KEY")
        if not api_key:
            st.error("KUMO_API_KEY not found in .env")
            st.stop()

        with st.spinner("Connecting to KumoRFM and building graph..."):
            try:
                rfm.init()
                graph = rfm.LocalGraph.from_data({
                    "customers": customers,
                    "orders": orders,
                    "products": products,
                    "events": events,
                })
                model = rfm.KumoRFM(graph)
                st.session_state["kumo_model"] = model
                st.session_state["kumo_graph"] = graph
                st.success("✅ KumoRFM initialized successfully! Relational graph built.")
                st.balloons()
            except Exception as e:
                st.error(f"Initialization failed: {e}")
                st.stop()
else:
    st.success("✅ KumoRFM model is ready (from this session)")

# ==================== INTERACTIVE PREDICTIONS ====================
if "kumo_model" in st.session_state:
    model = st.session_state["kumo_model"]

    st.divider()
    st.subheader("🎯 Live Predictions")

    tab1, tab2, tab3 = st.tabs(["Churn Risk", "Future Spend", "Custom PQL"])

    # --- Churn Risk ---
    with tab1:
        st.markdown("**Predict probability of no purchases/buys in the next N days**")
        selected_customers = st.multiselect(
            "Select Customer IDs", 
            customers["customer_id"].tolist(), 
            default=[1, 2, 5]
        )
        days = st.slider("Prediction horizon (days)", 30, 180, 90, step=30)

        if st.button("Predict Churn Risk", key="churn_btn"):
            if selected_customers:
                ids = ",".join(map(str, selected_customers))
                query = f"PREDICT COUNT(orders.*, 0, {days}, days)=0 FOR customers.customer_id IN ({ids})"
                with st.spinner("Running live KumoRFM prediction..."):
                    try:
                        result = model.predict(query)
                        st.dataframe(result, use_container_width=True)
                        st.caption(f"Query: `{query}`")
                    except Exception as e:
                        st.error(f"Prediction error: {e}")

    # --- Future Spend ---
    with tab2:
        st.markdown("**Predict total spend in the next N days**")
        cust_id = st.selectbox("Customer ID", customers["customer_id"].tolist(), index=0)
        spend_days = st.slider("Forecast horizon (days)", 30, 90, 30, key="spend_days")

        if st.button("Predict Future Spend", key="spend_btn"):
            query = f"PREDICT SUM(orders.amount, 0, {spend_days}, days) FOR customers.customer_id = {cust_id}"
            with st.spinner("Running live prediction..."):
                try:
                    result = model.predict(query)
                    st.dataframe(result, use_container_width=True)
                    st.caption(f"Query: `{query}`")
                except Exception as e:
                    st.error(f"Prediction error: {e}")

    # --- Custom PQL ---
    with tab3:
        st.markdown("**Run any PQL query** (advanced)")
        st.caption("Examples: `PREDICT COUNT(orders.*, 0, 90, days)=0 FOR customers.customer_id IN (1,2)`")
        custom_query = st.text_area(
            "Enter PQL Query", 
            value="PREDICT COUNT(orders.*, 0, 90, days)=0 FOR customers.customer_id IN (1,2,5)",
            height=100
        )
        if st.button("Run Custom Query", key="custom_btn"):
            with st.spinner("Querying KumoRFM..."):
                try:
                    result = model.predict(custom_query)
                    st.dataframe(result, use_container_width=True)
                except Exception as e:
                    st.error(f"Error: {e}")

    # ==================== GRAPH VISUALIZATION ====================
    st.divider()
    st.subheader("🕸️ Relational Graph (Inferred by KumoRFM)")

    if st.button("Show Graph"):
        G = nx.DiGraph()
        for _, r in customers.iterrows():
            G.add_node(f"C{r['customer_id']}", type="customer")
        for _, r in orders.iterrows():
            G.add_node(f"O{r['order_id']}", type="order")
        for _, r in products.iterrows():
            G.add_node(f"P{r['product_id']}", type="product")

        for _, r in orders.iterrows():
            G.add_edge(f"C{r['customer_id']}", f"O{r['order_id']}")
            G.add_edge(f"O{r['order_id']}", f"P{r['product_id']}")

        net = Network(height="500px", width="100%", bgcolor="#0E1117", font_color="#FAFAFA", directed=True)
        net.from_nx(G)
        color_map = {"customer": "#4ECDC4", "order": "#FF6B6B", "product": "#FFD93D"}
        for node in net.nodes:
            ntype = G.nodes[node["id"]].get("type", "customer")
            node["color"] = color_map.get(ntype, "#4ECDC4")

        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".html")
        net.save_graph(tmp.name)
        with open(tmp.name, "r", encoding="utf-8") as f:
            st.components.v1.html(f.read(), height=520)

st.caption("Made for testing KumoRFM live • Uses your .env key • Free tier has daily limits")
PYTHON_EOF

echo ""
echo "✅ Done! New interactive demo created: kumo_rfm_live_demo.py"
echo ""
echo "To run it:"
echo "   streamlit run kumo_rfm_live_demo.py"
echo ""
echo "Make sure your KUMO_API_KEY is set in .env"
