"""
Modern initialization for home page using the new Actual Budget API
"""

import os
import sys
import logging
from pathlib import Path

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent.parent.parent))

from dashboard.data_processor import create_processor_from_env
import utils.settings as config

logger = logging.getLogger(__name__)

def load_data():
    """Load and process data from Actual Budget API"""
    try:
        processor = create_processor_from_env()
        
        with processor.client:
            # Get basic data
            accounts = processor.accounts
            categories = processor.categories
            payees = processor.payees
            transactions = processor.transactions
            
            logger.info(f"Loaded {len(accounts)} accounts, {len(categories)} categories, "
                       f"{len(payees)} payees, {len(transactions)} transactions")
            
            # Process data for dashboard
            monthly_periods = processor.get_monthly_periods()
            tx_by_acct = processor.get_transactions_by_account()
            tx_by_cat = processor.get_transactions_by_category()
            
            nw_by_mth = processor.get_net_worth_by_month(tx_by_acct)
            cashflow_by_mth = processor.get_cashflow_by_month(tx_by_cat)
            
            metrics = processor.calculate_metrics(nw_by_mth, cashflow_by_mth)
            
            return {
                'ini': {
                    'accounts': accounts,
                    'categories': categories,
                    'payees': payees,
                    'transactions': transactions
                },
                'var': {
                    'months': monthly_periods,
                    'account_groups': config.account_groups,
                    'acct_group_sort': config.acct_group_sort,
                    'filter_payee_id': payees[
                        payees['name'].isin(config.cashflow_offbudget.get('filter_payees', []))
                    ]
                },
                'nw_by_mth': nw_by_mth,
                'cashflow_by_mth': cashflow_by_mth,
                'metrics': metrics,
                'tx_by_acct': tx_by_acct,
                'tx_by_cat': tx_by_cat
            }
            
    except Exception as e:
        logger.error(f"Error loading data: {e}")
        # Return empty data structure for graceful degradation
        return {
            'ini': {
                'accounts': [],
                'categories': [],
                'payees': [],
                'transactions': []
            },
            'var': {
                'months': [],
                'account_groups': config.account_groups,
                'acct_group_sort': config.acct_group_sort,
                'filter_payee_id': []
            },
            'nw_by_mth': {'all': [], 'assets': [], 'debts': []},
            'cashflow_by_mth': {'income': [], 'expenses': [], 'diff': []},
            'metrics': {},
            'tx_by_acct': {},
            'tx_by_cat': {}
        }

# Load data when module is imported (for backwards compatibility)
data = load_data()

# Expose variables for backwards compatibility with old code
ini = data['ini']
var = data['var']
nw_by_mth = data['nw_by_mth']
cashflow_by_mth = data['cashflow_by_mth']
metrics = data['metrics']
tx_by_acct = data['tx_by_acct']
tx_by_cat = data['tx_by_cat']

if __name__ == "__main__":
    # Test the data loading
    print("Data loaded successfully:")
    print(f"- Accounts: {len(ini['accounts'])}")
    print(f"- Categories: {len(ini['categories'])}")
    print(f"- Transactions: {len(ini['transactions'])}")
    print(f"- Monthly periods: {len(var['months'])}")
