import os
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

API_KEY=os.getenv("KUMO_API_KEY")

if not API_KEY:
    raise ValueError("Missing KUMO_API_KEY")

customers=pd.DataFrame({
    "customer_id":[1,2,3,4,5,6,7,8],
    "age":[22,45,31,52,23,40,36,28],
    "country":["US","US","CA","DE","FR","US","JP","CA"],
    "spent_last_month":[120,900,340,1500,80,620,710,230],
    "churn":[1,0,0,0,1,0,0,None]
})

print("\nDATA\n")
print(customers)

try:
    import kumoai

    print("\nKUMOAI\n")
    print(dir(kumoai))

except Exception as e:
    print("\nERROR\n")
    print(e)
