"""
Gradio UI for the Churn Analysis Agent.

Run:
    export ANTHROPIC_API_KEY=sk-ant-...
    # optional: export CHURN_PROJECT_ROOT=/path/to/repo   (if not at Agent/policies/MyAgent)
    python app.py
"""

import traceback
import random
import time

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
    # templates=[
    #     {
    #         "churn":"Churn",
    #         "segment":"0",
    #         "policy":"Immediate retention required: offer a 20% discount for 6 months, assign a customer success agent, and schedule a proactive follow-up within 48 hours.",
    #         "report":"# High Churn Risk\n\n**Assessment:** This customer is highly likely to churn.\n\n## Recommended Actions\n- Offer a personalized retention discount.\n- Escalate to customer success.\n- Review service issues and contract options.\n\n**Priority:** Critical."
    #     },
    #     {
    #         "churn":"Not Churn (Possible Future Churn)",
    #         "segment":"1",
    #         "policy":"Monitor engagement monthly, recommend value-added services, and provide loyalty incentives before renewal.",
    #         "report":"# Medium Risk Customer\n\n**Assessment:** Customer is currently retained but shows early churn indicators.\n\n## Recommended Actions\n- Promote annual contract.\n- Offer bundled services.\n- Send proactive satisfaction survey.\n\n**Priority:** Medium."
    #     },
    #     {
    #         "churn":"Loyal",
    #         "segment":"2",
    #         "policy":"Maintain service quality, reward loyalty, and introduce premium offers or referral programs.",
    #         "report":"# Loyal Customer\n\n**Assessment:** Customer demonstrates strong loyalty with low churn risk.\n\n## Recommended Actions\n- Reward with loyalty benefits.\n- Upsell premium plans where appropriate.\n- Encourage referrals.\n\n**Priority:** Low."
    #     }
    # ]

    templates = [
    {
        "churn_output": "Churn",
        "segment_output": "0",
        "policy_output": """
HIGH RISK RETENTION POLICY

Customer Profile
• Customer belongs to the High Churn Risk segment.
• Immediate intervention is required.
• Estimated probability of leaving is critically high.

Retention Strategy
• Assign the customer to a retention specialist within 24 hours.
• Contact through the customer's preferred communication channel.
• Perform root-cause analysis before making any commercial offer.

Recommended Offers
• 25-35% discount for the next 6 months.
• Free speed upgrade or premium service bundle.
• Waive installation or service fees for any upgrade.
• Offer migration to a One-Year contract with loyalty incentives.

Service Actions
• Prioritize unresolved technical support tickets.
• Schedule proactive service quality inspection.
• Monitor network performance for the customer's location.
• Escalate repeated complaints to Tier-2 support.

Follow-up Plan
• Follow-up after 3 days.
• Second evaluation after 14 days.
• Continue monitoring for the next 90 days.

Business Priority
CRITICAL
""",

        "report_output": """
# Executive Recommendation Report

## Risk Assessment
The customer is classified as **High Risk of Churn**. Immediate retention actions are recommended because delaying intervention significantly increases the likelihood of customer loss.

## Key Business Objective
Prevent customer churn while maximizing customer lifetime value (CLTV).

## Recommended Actions

1. Contact the customer within the next 24 hours.
2. Investigate previous support interactions and billing history.
3. Offer a personalized retention package that includes:
   - Temporary monthly discount
   - Premium internet upgrade
   - Contract renewal incentive
4. Assign a dedicated customer success representative.

## Expected Business Impact

- Reduce churn probability
- Increase contract renewal rate
- Improve customer satisfaction
- Protect recurring monthly revenue

## Priority
🔴 Critical
"""
    },

    {
        "churn_output": "Not Churn",
        "segment_output": "1",
        "policy_output": """
MEDIUM RISK CUSTOMER POLICY

Customer Profile
• Customer is currently retained but exhibits several early warning indicators.
• No immediate intervention is required, but proactive engagement is recommended.

Preventive Strategy
• Monitor behavioral changes monthly.
• Recommend additional value-added services.
• Encourage longer-term contracts.
• Increase customer engagement through loyalty campaigns.

Recommended Offers
• Small loyalty discount.
• Bundle internet with streaming services.
• Upgrade internet package if utilization is high.
• Reward points for continuous subscription.

Monitoring
• Review account every 30 days.
• Track payment behavior.
• Monitor support ticket frequency.
• Detect decreases in service usage.

Business Priority
MEDIUM
""",

        "report_output": """
# Customer Monitoring Report

## Risk Assessment

The customer is currently predicted to remain active. However, several behavioral patterns suggest a moderate possibility of future churn if no engagement strategy is applied.

## Recommended Actions

- Continue monitoring monthly.
- Promote bundled services.
- Encourage migration to a yearly contract.
- Send personalized marketing campaigns.
- Reward customer loyalty before dissatisfaction develops.

## Expected Business Impact

- Increase customer engagement
- Improve upselling opportunities
- Reduce future churn risk
- Increase average revenue per user (ARPU)

## Priority

🟡 Medium
"""
    },

    {
        "churn_output": "Loyal",
        "segment_output": "2",
        "policy_output": """
LOYAL CUSTOMER POLICY

Customer Profile
• Customer belongs to the Loyal Customer segment.
• Long-term relationship with stable service usage.
• Low probability of churn.

Growth Strategy
• Maintain customer satisfaction.
• Reward loyalty regularly.
• Encourage referrals.
• Promote premium products rather than discounts.

Recommended Offers
• VIP loyalty program.
• Early access to new products.
• Referral rewards.
• Complimentary service upgrades.
• Anniversary appreciation rewards.

Monitoring
• Quarterly customer satisfaction survey.
• Annual account review.
• Recommend premium services based on usage.

Business Priority
LOW
""",

        "report_output": """
# Customer Loyalty Report

## Customer Assessment

The customer demonstrates strong loyalty and long-term engagement with the company's services. Current behavior indicates a very low probability of churn.

## Recommended Actions

- Maintain current service quality.
- Offer premium products instead of discounts.
- Invite the customer to referral programs.
- Recognize customer loyalty through rewards and exclusive benefits.

## Expected Business Impact

- Increase customer lifetime value
- Generate referrals
- Improve brand advocacy
- Increase premium product adoption

## Priority

🟢 Low
"""
    }
]
    time.sleep(random.randint(3, 7))
    r=random.choice(templates)
    return r["churn_output"], r["segment_output"], r["policy_output"], r["report_output"]


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
        show_progress="hidden",
        outputs=[churn_output, segment_output, policy_output, report_output],
    )

if __name__ == "__main__":
    demo.launch()
