import os
import sqlite3
import pandas as pd
import streamlit as st
import plotly.express as px
import networkx as nx
from pyvis.network import Network
import tempfile
from dotenv import load_dotenv

load_dotenv()

st.set_page_config(page_title="Relational Sandbox + KumoRFM", layout="wide")
st.title("Multi-Table Relational Dataset Sandbox")
st.caption("Local relational simulation + optional KumoRFM integration")

conn = sqlite3.connect(":memory:")

customers = pd.DataFrame({
    "customer_id": [1,2,3,4,5,6,7,8],
    "age": [22,45,31,52,23,40,36,28],
    "country": ["US","US","CA","DE","FR","US","JP","CA"]
})

orders = pd.DataFrame({
    "order_id": [101,102,103,104,105,106,107,108,109],
    "customer_id": [1,1,2,3,4,5,6,7,8],
    "product_id": [201,202,203,204,205,206,207,208,209],
    "amount": [120,340,900,1500,80,620,710,230,400]
})

products = pd.DataFrame({
    "product_id": [201,202,203,204,205,206,207,208,209],
    "category": ["A","B","A","C","B","A","C","B","A"]
})

events = pd.DataFrame({
    "event_id": list(range(1,11)),
    "customer_id": [1,1,2,3,4,5,6,7,8,8],
    "event_type": ["view","buy","view","view","buy","view","buy","view","buy","view"]
})

customers.to_sql("customers", conn, if_exists="replace", index=False)
orders.to_sql("orders", conn, if_exists="replace", index=False)
products.to_sql("products", conn, if_exists="replace", index=False)
events.to_sql("events", conn, if_exists="replace", index=False)

with st.expander("Raw Tables (Source Data)", expanded=False):
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Customers")
        st.dataframe(customers, use_container_width=True, hide_index=True)
        st.subheader("Products")
        st.dataframe(products, use_container_width=True, hide_index=True)
    with col2:
        st.subheader("Orders")
        st.dataframe(orders, use_container_width=True, hide_index=True)
        st.subheader("Events")
        st.dataframe(events, use_container_width=True, hide_index=True)

st.subheader("Relational Feature Table (SQL Join)")
query = """
SELECT
    c.customer_id,
    c.age,
    c.country,
    COUNT(o.order_id) AS num_orders,
    COALESCE(SUM(o.amount), 0) AS total_spend,
    COUNT(CASE WHEN e.event_type = 'buy' THEN 1 END) AS buy_events
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN events e ON c.customer_id = e.customer_id
GROUP BY c.customer_id, c.age, c.country
ORDER BY total_spend DESC
"""
features = pd.read_sql_query(query, conn)
st.dataframe(features, use_container_width=True, hide_index=True)

st.subheader("Relational Analytics")
fig = px.scatter(
    features, x="age", y="total_spend", size="num_orders", color="country",
    hover_data=["customer_id", "buy_events"],
    title="Customer Value vs Age"
)
st.plotly_chart(fig, use_container_width=True)

st.subheader("Heterogeneous Relational Graph")
st.caption("Nodes: Customers (C), Orders (O), Products (P) - Real relationships")

G = nx.Graph()
for _, r in customers.iterrows():
    G.add_node(f"C{r['customer_id']}", node_type="customer", size=25)
for _, r in orders.iterrows():
    G.add_node(f"O{r['order_id']}", node_type="order", size=15)
for _, r in products.iterrows():
    G.add_node(f"P{r['product_id']}", node_type="product", size=18)
for _, r in orders.iterrows():
    G.add_edge(f"C{r['customer_id']}", f"O{r['order_id']}")
    G.add_edge(f"O{r['order_id']}", f"P{r['product_id']}")

net = Network(height="520px", width="100%", bgcolor="#0E1117", font_color="#FAFAFA")
net.from_nx(G)
color_map = {"customer": "#4ECDC4", "order": "#FF6B6B", "product": "#FFD93D"}
for node in net.nodes:
    ntype = G.nodes[node["id"]].get("node_type", "customer")
    node["color"] = color_map.get(ntype, "#4ECDC4")
    node["size"] = G.nodes[node["id"]].get("size", 20)
tmp_dir = tempfile.gettempdir()
graph_path = os.path.join(tmp_dir, "relational_graph.html")
net.save_graph(graph_path)
with open(graph_path, "r", encoding="utf-8") as f:
    st.components.v1.html(f.read(), height=540)

st.divider()
st.subheader("KumoRFM Integration (Optional)")
kumo_key = os.getenv("KUMO_API_KEY")
if kumo_key:
    st.success("KUMO_API_KEY detected")
    try:
        import kumoai
        st.write(f"Kumo SDK version: {kumoai.__version__}")
        st.info("This multi-table structure is ideal for KumoRFM")
        if st.button("Run KumoRFM-style Prediction"):
            with st.spinner("Processing..."):
                st.success("KumoRFM ready for relational predictions")
    except Exception as e:
        st.error(f"Kumo error: {e}")
else:
    st.warning("No KUMO_API_KEY found. Create .env file to enable.")
    st.code("KUMO_API_KEY=your_key_here", language="bash")
    st.caption("Get a free key at https://kumorfm.ai")

st.subheader("Quick Insights")
c1, c2, c3 = st.columns(3)
c1.metric("Customers", len(customers))
c2.metric("Orders", len(orders))
c3.metric("Avg Order Value", f"${orders['amount'].mean():.2f}")
st.caption("Relational modeling foundation for KumoRFM")
