import pandas as pd

from dataload.jic_inflation_rates import transform_inflation_rates


def test_transform_inflation_rates_normalizes_columns_and_types():
    df = pd.DataFrame([
        {"Column 0": "ignore", "baseyear": "2024", "targetyear": "2025", "APPN": "OMA", "type": "ThenToThen", "amount": "1.0214"},
    ])

    result = transform_inflation_rates(df, "202501")

    assert result.to_dict(orient="records") == [
        {
            "amcos_version_id": "202501",
            "base_year": 2024,
            "target_year": 2025,
            "appropriation": "OMA",
            "rate_type": "ThenToThen",
            "amount": 1.0214,
        }
    ]
