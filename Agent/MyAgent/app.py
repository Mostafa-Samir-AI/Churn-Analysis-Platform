"""
Gradio UI for the Churn Analysis Agent.

Run:
    export ANTHROPIC_API_KEY=sk-ant-...
    # optional: export CHURN_PROJECT_ROOT=/path/to/repo   (if not at Agent/policies/MyAgent)
    python app.py
"""

import traceback

import gradio as gr

from agent import ChurnAgent

agent = None  # lazy-loaded so the UI still opens even if artifacts are missing


def get_agent():
    global agent
    if agent is None:
        agent = ChurnAgent()
    return agent


def analyze_customer(
    gender, senior_citizen, partner, dependents, tenure,
    phone_service, multiple_lines, internet_service,
    online_security, online_backup, device_protection, tech_support,
    streaming_tv, streaming_movies, contract, paperless_billing,
    payment_method, monthly_charges, total_charges,
):
    raw_customer = {
        "gender": gender,
        "SeniorCitizen": 1 if senior_citizen else 0,
        "Partner": partner,
        "Dependents": dependents,
        "tenure": int(tenure),
        "PhoneService": phone_service,
        "MultipleLines": multiple_lines,
        "InternetService": internet_service,
        "OnlineSecurity": online_security,
        "OnlineBackup": online_backup,
        "DeviceProtection": device_protection,
        "TechSupport": tech_support,
        "StreamingTV": streaming_tv,
        "StreamingMovies": streaming_movies,
        "Contract": contract,
        "PaperlessBilling": paperless_billing,
        "PaymentMethod": payment_method,
        "MonthlyCharges": float(monthly_charges),
        "TotalCharges": float(total_charges) if total_charges else tenure * monthly_charges,
    }

    try:
        result = get_agent().analyze(raw_customer)
    except Exception as e:
        return (
            f"⚠️ Error: {e}",
            "n/a",
            "n/a",
            f"```\n{traceback.format_exc()}\n```",
        )

    churn = result["churn"]
    segment = result["segment"]

    prob_label = f"{churn['churn_probability']:.1%} ({churn['risk_tier']} risk) — {churn['prediction']}"
    segment_label = f"Cluster {segment['cluster_id']}"

    return prob_label, segment_label, result["policy_context"], result["report"]


with gr.Blocks(title="Churn Analysis Agent") as demo:
    gr.Markdown("# Churn Analysis Agent\nEnter a customer's profile to get a churn prediction, "
                "segment, and an AI-generated retention recommendation.")

    with gr.Row():
        with gr.Column():
            gr.Markdown("### Customer Profile")
            gender = gr.Radio(["Female", "Male"], value="Female", label="Gender")
            senior_citizen = gr.Checkbox(label="Senior Citizen")
            partner = gr.Radio(["Yes", "No"], value="No", label="Has Partner")
            dependents = gr.Radio(["Yes", "No"], value="No", label="Has Dependents")
            tenure = gr.Slider(0, 72, value=12, step=1, label="Tenure (months)")

            gr.Markdown("### Services")
            phone_service = gr.Radio(["Yes", "No"], value="Yes", label="Phone Service")
            multiple_lines = gr.Dropdown(["No", "No phone service", "Yes"], value="No", label="Multiple Lines")
            internet_service = gr.Dropdown(["DSL", "Fiber optic", "No"], value="Fiber optic", label="Internet Service")
            online_security = gr.Dropdown(["No", "No internet service", "Yes"], value="No", label="Online Security")
            online_backup = gr.Dropdown(["No", "No internet service", "Yes"], value="No", label="Online Backup")
            device_protection = gr.Dropdown(["No", "No internet service", "Yes"], value="No", label="Device Protection")
            tech_support = gr.Dropdown(["No", "No internet service", "Yes"], value="No", label="Tech Support")
            streaming_tv = gr.Dropdown(["No", "No internet service", "Yes"], value="No", label="Streaming TV")
            streaming_movies = gr.Dropdown(["No", "No internet service", "Yes"], value="No", label="Streaming Movies")

            gr.Markdown("### Account")
            contract = gr.Dropdown(["Month-to-month", "One year", "Two year"], value="Month-to-month", label="Contract")
            paperless_billing = gr.Radio(["Yes", "No"], value="Yes", label="Paperless Billing")
            payment_method = gr.Dropdown(
                ["Bank transfer (automatic)", "Credit card (automatic)", "Electronic check", "Mailed check"],
                value="Electronic check", label="Payment Method",
            )
            monthly_charges = gr.Slider(18.25, 118.75, value=70.0, step=0.05, label="Monthly Charges ($)")
            total_charges = gr.Number(label="Total Charges ($) — leave 0 to auto-calc from tenure × monthly", value=0)

            submit_btn = gr.Button("Analyze Customer", variant="primary")

        with gr.Column():
            gr.Markdown("### Results")
            churn_output = gr.Textbox(label="Churn Prediction")
            segment_output = gr.Textbox(label="Customer Segment")
            policy_output = gr.Textbox(label="Retrieved Policy Context", lines=6)
            report_output = gr.Markdown(label="AI Recommendation Report")

    submit_btn.click(
        fn=analyze_customer,
        inputs=[
            gender, senior_citizen, partner, dependents, tenure,
            phone_service, multiple_lines, internet_service,
            online_security, online_backup, device_protection, tech_support,
            streaming_tv, streaming_movies, contract, paperless_billing,
            payment_method, monthly_charges, total_charges,
        ],
        outputs=[churn_output, segment_output, policy_output, report_output],
    )

if __name__ == "__main__":
    demo.launch()
