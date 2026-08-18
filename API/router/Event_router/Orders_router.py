from fastapi import APIRouter
from controllers.Event_Controllers.OrdersInfo_controllers import (
    create_order, get_all_Orders, get_order_by_id, get_orders_by_account_id,
    update_order, delete_order
)
from controllers.Event_Controllers.PaymentTypeInfo_controllers import (
    create_paymenttype, get_all_PaymentTypes, get_paymenttype_by_id,
    update_paymenttype, delete_paymenttype
)

router = APIRouter(prefix="/orders", tags=["Orders"])

# ordersinfo
router.post("/order/create")(create_order)
router.get("/order/all")(get_all_Orders)
router.get("/order/{order_id}")(get_order_by_id)
router.get("/order/by-account/{account_id}")(get_orders_by_account_id)
router.put("/order/update")(update_order)
router.delete("/order/{order_id}")(delete_order)

# paymenttypeinfo
router.post("/paymenttype/create")(create_paymenttype)
router.get("/paymenttype/all")(get_all_PaymentTypes)
router.get("/paymenttype/{payment_type_id}")(get_paymenttype_by_id)
router.put("/paymenttype/update")(update_paymenttype)
router.delete("/paymenttype/{payment_type_id}")(delete_paymenttype)
