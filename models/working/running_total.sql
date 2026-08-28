select
    transaction_id,
    account_id,
    transaction_date,
    amount,
    transaction_type,
    sum(
        case
            when transaction_type = 'Deposit'
            then amount
            when transaction_type = 'Withdrawal'
            then - amount
            else null
        end
    ) over (partition by account_id order by transaction_date) as running_total
from test.raw.account_transactions
