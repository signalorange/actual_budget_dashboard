"""
Modern data processing module for Actual Budget Dashboard
Uses the new Actual Budget API instead of direct SQLite access
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
import logging
from pathlib import Path
import sys

# Add parent directory to path to import our API client
sys.path.append(str(Path(__file__).parent.parent))
from actual_api_client import ActualBudgetClient
from utils.functions import moving_average
import utils.settings as config

logger = logging.getLogger(__name__)


class ActualDataProcessor:
    """Modern data processor for Actual Budget data"""
    
    def __init__(self, client: ActualBudgetClient):
        self.client = client
        self._accounts_cache = None
        self._categories_cache = None
        self._payees_cache = None
        self._transactions_cache = None
    
    def refresh_data(self) -> None:
        """Refresh all cached data from the API"""
        logger.info("Refreshing data from Actual Budget API...")
        self._accounts_cache = None
        self._categories_cache = None
        self._payees_cache = None
        self._transactions_cache = None
        
    @property
    def accounts(self) -> pd.DataFrame:
        """Get accounts as DataFrame"""
        if self._accounts_cache is None:
            accounts_data = self.client.get_accounts()
            self._accounts_cache = pd.DataFrame(accounts_data)
            if not self._accounts_cache.empty:
                # Convert balance from integer cents to decimal
                self._accounts_cache['balance'] = self._accounts_cache['balance'].fillna(0) / 100
        return self._accounts_cache
    
    @property
    def categories(self) -> pd.DataFrame:
        """Get categories as DataFrame"""
        if self._categories_cache is None:
            categories_data = self.client.get_categories()
            self._categories_cache = pd.DataFrame(categories_data)
        return self._categories_cache
    
    @property
    def payees(self) -> pd.DataFrame:
        """Get payees as DataFrame"""
        if self._payees_cache is None:
            payees_data = self.client.get_payees()
            self._payees_cache = pd.DataFrame(payees_data)
        return self._payees_cache
    
    @property
    def transactions(self) -> pd.DataFrame:
        """Get transactions as DataFrame"""
        if self._transactions_cache is None:
            transactions_data = self.client.get_transactions()
            self._transactions_cache = pd.DataFrame(transactions_data)
            if not self._transactions_cache.empty:
                # Convert date from string to datetime
                self._transactions_cache['date'] = pd.to_datetime(
                    self._transactions_cache['date'], format='%Y-%m-%d'
                )
                # Convert amount from integer cents to decimal
                self._transactions_cache['amount'] = self._transactions_cache['amount'].fillna(0) / 100
        return self._transactions_cache
    
    def get_date_range(self) -> Tuple[datetime, datetime]:
        """Get the date range of available transactions"""
        transactions = self.transactions
        if transactions.empty:
            return datetime.now(), datetime.now()
        
        return transactions['date'].min(), transactions['date'].max()
    
    def get_monthly_periods(self) -> List[str]:
        """Get list of available monthly periods"""
        start_date, end_date = self.get_date_range()
        
        periods = []
        current = start_date.replace(day=1)
        
        while current <= end_date:
            periods.append(current.strftime('%Y-%m'))
            # Move to next month
            if current.month == 12:
                current = current.replace(year=current.year + 1, month=1)
            else:
                current = current.replace(month=current.month + 1)
        
        return periods
    
    def get_transactions_by_account(self) -> Dict[str, Dict[str, Any]]:
        """Get transactions grouped by account and month"""
        transactions = self.transactions
        accounts = self.accounts
        monthly_periods = self.get_monthly_periods()
        
        tx_by_acct = {}
        
        for _, account in accounts.iterrows():
            account_id = account['id']
            tx_by_acct[account_id] = {}
            
            # Get all transactions for this account
            account_txs = transactions[transactions['account'] == account_id].copy()
            tx_by_acct[account_id]['all'] = account_txs
            tx_by_acct[account_id]['sum'] = []
            
            # Group by month
            for period in monthly_periods:
                month_txs = account_txs[
                    account_txs['date'].dt.to_period('M').astype(str) == period
                ]
                tx_by_acct[account_id][period] = month_txs
                tx_by_acct[account_id]['sum'].append(month_txs['amount'].sum())
        
        return tx_by_acct
    
    def get_transactions_by_category(self) -> Dict[str, Dict[str, Any]]:
        """Get transactions grouped by category and month"""
        transactions = self.transactions
        categories = self.categories
        monthly_periods = self.get_monthly_periods()
        
        tx_by_cat = {}
        
        for _, category in categories.iterrows():
            category_id = category['id']
            tx_by_cat[category_id] = {}
            
            # Get all transactions for this category
            category_txs = transactions[transactions['category'] == category_id].copy()
            tx_by_cat[category_id]['all'] = category_txs
            tx_by_cat[category_id]['sum'] = []
            
            # Group by month
            for period in monthly_periods:
                month_txs = category_txs[
                    category_txs['date'].dt.to_period('M').astype(str) == period
                ]
                tx_by_cat[category_id][period] = month_txs
                tx_by_cat[category_id]['sum'].append(month_txs['amount'].sum())
        
        return tx_by_cat
    
    def get_net_worth_by_month(self, tx_by_acct: Optional[Dict] = None) -> Dict[str, List[float]]:
        """Calculate net worth by month using account groups from config"""
        if tx_by_acct is None:
            tx_by_acct = self.get_transactions_by_account()
        
        monthly_periods = self.get_monthly_periods()
        accounts = self.accounts
        
        # Initialize result structure
        nw_by_mth = {key: [] for key in config.account_groups}
        nw_by_mth.update({
            'all': [],
            'assets': [],
            'debts': []
        })
        
        for i, period in enumerate(monthly_periods):
            nw_by_mth['all'].append(0)
            nw_by_mth['assets'].append(0)
            nw_by_mth['debts'].append(0)
            
            for group_name, account_names in config.account_groups.items():
                # Find accounts in this group
                group_accounts = accounts[accounts['name'].isin(account_names)]
                nw_by_mth[group_name].append(0)
                
                for _, account in group_accounts.iterrows():
                    account_id = account['id']
                    if account_id in tx_by_acct:
                        month_sum = tx_by_acct[account_id][period]['amount'].sum()
                        nw_by_mth[group_name][i] += month_sum
                
                # Add previous month's balance for cumulative calculation
                if i > 0:
                    nw_by_mth[group_name][i] += nw_by_mth[group_name][i-1]
                
                # Add to total
                nw_by_mth['all'][i] += nw_by_mth[group_name][i]
                
                # Categorize as assets or debts
                if group_name.startswith('assets_'):
                    nw_by_mth['assets'][i] += nw_by_mth[group_name][i]
                elif group_name.startswith('liabilities_'):
                    nw_by_mth['debts'][i] += nw_by_mth[group_name][i]
        
        return nw_by_mth
    
    def get_cashflow_by_month(self, tx_by_cat: Optional[Dict] = None) -> Dict[str, Any]:
        """Calculate cashflow by month"""
        if tx_by_cat is None:
            tx_by_cat = self.get_transactions_by_category()
        
        monthly_periods = self.get_monthly_periods()
        categories = self.categories
        
        # Apply filtering from config
        if config.cashflow_filter_first_mo:
            monthly_periods = monthly_periods[1:]
        if config.cashflow_filter_current_mo:
            monthly_periods = monthly_periods[:-1]
        
        # Initialize cashflow structure
        cashflow_by_mth = {}
        for _, cat_group in categories.groupby('group_id'):
            group_id = cat_group['group_id'].iloc[0]
            cashflow_by_mth[group_id] = []
        
        cashflow_by_mth.update({
            'income': [],
            'income_pre_tax': [],
            'expenses': [],
            'diff': []
        })
        
        for period in monthly_periods:
            cashflow_by_mth['income'].append(0)
            cashflow_by_mth['income_pre_tax'].append(0)
            cashflow_by_mth['expenses'].append(0)
            
            # Process each category group
            for group_id in cashflow_by_mth.keys():
                if group_id in ['income', 'income_pre_tax', 'expenses', 'diff']:
                    continue
                    
                if group_id not in cashflow_by_mth:
                    cashflow_by_mth[group_id] = []
                
                group_categories = categories[categories['group_id'] == group_id]
                month_total = 0
                
                for _, category in group_categories.iterrows():
                    cat_id = category['id']
                    if cat_id in tx_by_cat and period in tx_by_cat[cat_id]:
                        txns = tx_by_cat[cat_id][period]
                        # Filter out transfers and specific payees
                        filtered_txns = txns[
                            txns['transfer_id'].isnull() &
                            ~txns['payee'].isin(config.cashflow_offbudget.get('filter_payees', []))
                        ]
                        month_total += filtered_txns['amount'].sum()
                
                cashflow_by_mth[group_id].append(month_total)
                
                # Categorize as income or expense
                if group_categories['is_income'].all():
                    cashflow_by_mth['income'][-1] += month_total
                else:
                    cashflow_by_mth['expenses'][-1] += month_total
            
            # Calculate difference
            period_diff = cashflow_by_mth['income'][-1] + cashflow_by_mth['expenses'][-1]
            cashflow_by_mth['diff'].append(period_diff)
        
        # Add moving averages
        for group_id in list(cashflow_by_mth.keys()):
            if group_id in ['income', 'income_pre_tax', 'expenses', 'diff']:
                continue
            if len(cashflow_by_mth[group_id]) >= 6:
                cashflow_by_mth[f'{group_id}_6moMA'] = moving_average(
                    cashflow_by_mth[group_id], 6
                ).tolist()
        
        # Add moving averages for main categories
        for key in ['income', 'income_pre_tax', 'expenses', 'diff']:
            if len(cashflow_by_mth[key]) >= 6:
                cashflow_by_mth[f'{key}_6moMA'] = moving_average(
                    cashflow_by_mth[key], 6
                ).tolist()
            if len(cashflow_by_mth[key]) >= 12:
                cashflow_by_mth[f'{key}_12moMA'] = moving_average(
                    cashflow_by_mth[key], 12
                ).tolist()
        
        return cashflow_by_mth
    
    def calculate_metrics(self, nw_by_mth: Dict, cashflow_by_mth: Dict) -> Dict[str, Dict]:
        """Calculate financial metrics"""
        monthly_periods = self.get_monthly_periods()
        
        # Apply same filtering as cashflow
        first_mo_offset = 1 if config.cashflow_filter_first_mo else 0
        last_mo_offset = -1 if config.cashflow_filter_current_mo else None
        
        metrics = {}
        
        # Savings Rate = 1 - expenses/income
        if cashflow_by_mth['income'] and cashflow_by_mth['expenses']:
            income = np.array(cashflow_by_mth['income'])
            expenses = np.array(cashflow_by_mth['expenses'])
            
            # Avoid division by zero
            income_safe = np.where(income == 0, 0.01, income)
            
            metrics['savings_rate'] = {
                'monthly': (1 + expenses / income_safe).tolist(),
                '6moMA': [],
                '12moMA': []
            }
            
            if '6moMA' in [k for k in cashflow_by_mth.keys() if k.endswith('_6moMA')]:
                income_6mo = np.array(cashflow_by_mth.get('income_6moMA', []))
                expenses_6mo = np.array(cashflow_by_mth.get('expenses_6moMA', []))
                if len(income_6mo) > 0 and len(expenses_6mo) > 0:
                    income_6mo_safe = np.where(income_6mo == 0, 0.01, income_6mo)
                    metrics['savings_rate']['6moMA'] = (1 + expenses_6mo / income_6mo_safe).tolist()
        
        return metrics


def create_processor_from_env() -> ActualDataProcessor:
    """Create data processor using environment configuration"""
    from actual_api_client import create_client_from_env
    
    client = create_client_from_env()
    return ActualDataProcessor(client)


# Example usage
if __name__ == "__main__":
    try:
        processor = create_processor_from_env()
        
        # Test the processor
        with processor.client:
            print("Accounts:", len(processor.accounts))
            print("Categories:", len(processor.categories))
            print("Transactions:", len(processor.transactions))
            
            periods = processor.get_monthly_periods()
            print(f"Monthly periods: {periods[:3]}...{periods[-3:]} ({len(periods)} total)")
            
    except Exception as e:
        logger.error(f"Error testing processor: {e}")
        print(f"Error: {e}")
