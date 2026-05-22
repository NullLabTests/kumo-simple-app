import pandas as pd
import streamlit as st
import plotly.express as px
import networkx as nx
from pyvis.network import Network
import tempfile
import os
import kumoai

st.set_page_config(
    page_title="Kumo Relational Demo",
    layout="wide"
)

st.title("Kumo Relational ML Demo")

st.markdown(
    """
A lightweight visual demonstration of:
- relational data
- customer churn
- graph structure
- Kumo SDK integration
"""
)

data = pd.DataFrame({
    "customer_id": [1,2,3,4,5,6,7,8],
    "age": [22,45,31,52,23,40,36,28],
    "country": ["US","US","CA","DE","FR","US","JP","CA"],
    "spent_last_month": [120,900,340,1500,80,620,710,230],
    "churn": [1,0,0,0,1,0,0,None]
})

st.subheader("Dataset")

st.dataframe(data, use_container_width=True)

left, right = st.columns(2)

with left:
    fig = px.histogram(
        data,
        x="country",
        title="Customers by Country"
    )
    st.plotly_chart(fig, use_container_width=True)

with right:
    fig2 = px.scatter(
        data,
        x="age",
        y="spent_last_month",
        color="country",
        size="spent_last_month",
        title="Customer Spend vs Age"
    )
    st.plotly_chart(fig2, use_container_width=True)

st.subheader("Relational Graph")

graph = nx.Graph()

for _, row in data.iterrows():
    cid = f"C{row['customer_id']}"
    graph.add_node(
        cid,
        label=cid,
        country=row["country"]
    )

for i in range(len(data)):
    for j in range(i + 1, len(data)):
        if data.iloc[i]["country"] == data.iloc[j]["country"]:
            graph.add_edge(
                f"C{data.iloc[i]['customer_id']}",
                f"C{data.iloc[j]['customer_id']}"
            )

net = Network(height="500px", width="100%")

for node in graph.nodes():
    net.add_node(node, label=node)

for edge in graph.edges():
    net.add_edge(edge[0], edge[1])

tmp_dir = tempfile.gettempdir()
html_path = os.path.join(tmp_dir, "kumo_graph.html")

net.save_graph(html_path)

with open(html_path, "r", encoding="utf-8") as f:
    html = f.read()

st.components.v1.html(html, height=520)

st.subheader("Kumo SDK")

st.code(f"Kumo SDK version: {kumoai.__version__}")

st.markdown(
    """
This app demonstrates:
- local Kumo SDK integration
- relational customer structure
- graph-connected entities
- lightweight churn analysis
"""
)
