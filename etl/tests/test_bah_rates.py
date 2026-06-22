import pandas as pd

from dataload.bah_rates import transform_bah_rate_matrix


def test_transform_bah_rate_matrix_unpivots_grades():
    df = pd.DataFrame([
        {"MHA": "001", "E1": "1000.00", "E2": "1100.25", "O1E": "1500.50"},
    ])

    result = transform_bah_rate_matrix(df, with_dependents=True, version_id="202501")

    assert list(result["grade"]) == ["E1", "E2", "O1E"]
    assert list(result["grade_type"]) == ["E", "E", "OE"]
    assert list(result["grade_level"]) == [1, 2, 1]
    assert result["with_dependents"].tolist() == [True, True, True]
    assert result["amount"].tolist() == [1000.0, 1100.25, 1500.5]
