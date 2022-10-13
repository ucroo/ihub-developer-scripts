for cust in ucroo/* ucroo-community/*; do
    echo "Validating: $cust"
    (
        cd $cust;
        if ! validateFlowEntities.sh . ; then
            exit 1
        fi
        break

    )
    done
