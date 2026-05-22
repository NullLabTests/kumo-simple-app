# kumo-simple-app

Multi-Table Relational Dataset Sandbox + KumoRFM Integration

## Screenshots

### Main Dashboard
![Dashboard](images/ss1.png)

### Relational Graph + Kumo Section
![Graph](images/ss2.png)

## Features
-A clean, interactive demo that shows how to work with KumoRFM on real multi-table data
=Includes graph construction and live predictions via the KumoRFM API.

## Quick Start
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
streamlit run dashboard.py
```

## Interactive KumoRFM Demo

Run the live demo with real KumoRFM API calls:

```bash
./setup_kumo_interactive_demo.sh
streamlit run kumo_rfm_live_demo.py


