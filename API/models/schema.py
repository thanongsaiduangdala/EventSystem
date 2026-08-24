from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, date

class CheckDuplicateRequest(BaseModel):
    email: str
    phonenum: str

class VerifyOtpRequest(BaseModel):
    email: str
    otp: str

class DeleteCustomerRequest(BaseModel):
    account_id: int

class SignupOtpRequest(BaseModel):
    email: str

class SignUpRequest(BaseModel):
    firstname: str
    lastname: str
    phonenum: str
    email: str
    password: str
    otp: str

class LoginRequest(BaseModel):
    email: str
    password: str

class SendOtpRequest(BaseModel):
    email: str

class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str

class AddEventInfoRequest(BaseModel):
    EventName: str
    EventStartingYMDT: str
    EventEndingYMDT: str
    EventAddress: str
    EventDescription: str
    EventOrganizerID: int
    Longitude: float
    Latitude: float

class UpdateEventInfoRequest(BaseModel):
    EventID: int
    EventName: str
    EventStartingYMDT: str
    EventEndingYMDT: str
    EventAddress: str
    EventDescription: str
    EventOrganizerID: int
    Longitude: float
    Latitude: float

class AddTicketTypeRequest(BaseModel):
    EventID: int
    TypeName: str
    PriceInKip: int
    Capacity: int
    SaleStart: str
    SaleEnd: str

class UpdateTicketTypeRequest(BaseModel):
    TicketTypeID: int
    EventID: int
    TypeName: str
    PriceInKip: int
    Capacity: int
    SaleStart: str
    SaleEnd: str

class AddEventQuestionInfo(BaseModel):
    EventID: int
    EventQuestion: str
    EventQuestionTypeID: int
    IsRequire: bool
    SortOrder: int
    Options: Optional[List[str]] = None  
 
 
class UpdateEventQuestionInfo(BaseModel):
    EventQuestionID: int
    EventID: int
    EventQuestion: str
    EventQuestionTypeID: int
    IsRequire: bool
    SortOrder: int
    Options: Optional[List[str]] = None
 
 
class AddEventQuestionType(BaseModel):
    EventQuestionType: str
 
 
class UpdateEventQuestionType(BaseModel):
    EventQuestionTypeID: int
    EventQuestionType: str

class AddEventImageInfoRequest(BaseModel):
    EventID: int
    ImageName: str
    ImagePath: str

class UpdateEventImageInfoRequest(BaseModel):
    ImageID: int
    EventID: int
    ImageName: str
    ImagePath: str

class AddEventSponserInfoRequest(BaseModel):
    EventID: int
    SponserID: int

class UpdateEventSponserInfoRequest(BaseModel):
    EventSponserID: int
    EventID: int
    SponserID: int

class AddSponserInfoRequest(BaseModel):
    SponserName: str
    SponserLogoPath: str

class UpdateSponserInfoRequest(BaseModel):
    SponserID: int
    SponserName: str
    SponserLogoPath: str

# ---------- categoryinfo ----------
class AddCategoryInfoRequest(BaseModel):
    CategoryName: str
    CategoryIconPath: str
 
 
class UpdateCategoryInfoRequest(BaseModel):
    CategoryID: int
    CategoryName: str
    CategoryIconPath: str
 
 
# ---------- eventcategoryinfo ----------
class AddEventCategoryInfoRequest(BaseModel):
    EventID: int
    CategoryID: int
 
 
class UpdateEventCategoryInfoRequest(BaseModel):
    EventCategoryID: int
    EventID: int
    CategoryID: int
 
 
# ---------- eventorganizerInfo ----------
class AddEventOrganizerInfoRequest(BaseModel):
    EventOrganizerName: str
    EventOrganizerLogoPath: str
    CreatedByAccountID: int
    EventOrganizerDiscription: Optional[str] = None
 
 
class UpdateEventOrganizerInfoRequest(BaseModel):
    EventOrganizerID: int
    EventOrganizerName: str
    EventOrganizerLogoPath: str
    CreatedByAccountID: int
    EventOrganizerDiscription: Optional[str] = None
 
 
# ---------- organizermember ----------
class AddOrganizerMemberRequest(BaseModel):
    AccountID: int
    EventOrganizerID: int
    TeamRoleID: int
 
 
class UpdateOrganizerMemberRequest(BaseModel):
    MemberID: int
    AccountID: int
    EventOrganizerID: int
    TeamRoleID: int
 
 
# ---------- eventRole ----------
class AddEventRoleRequest(BaseModel):
    RoleName: str
 
 
class UpdateEventRoleRequest(BaseModel):
    EventRoleID: int
    RoleName: str
 
 
# ---------- eventstaff ----------
class AddEventStaffRequest(BaseModel):
    EventID: int
    MemberID: int
    EventRoleID: int
    AssignedAtYMDT: Optional[datetime] = None
 
 
class UpdateEventStaffRequest(BaseModel):
    AssignmentID: int
    EventID: int
    MemberID: int
    EventRoleID: int
    AssignedAtYMDT: Optional[datetime] = None

# ---------- categoryinfo ----------
class AddCategoryInfoRequest(BaseModel):
    CategoryName: str
    CategoryIconPath: str
 
 
class UpdateCategoryInfoRequest(BaseModel):
    CategoryID: int
    CategoryName: str
    CategoryIconPath: str
 
 
# ---------- eventcategoryinfo ----------
class AddEventCategoryInfoRequest(BaseModel):
    EventID: int
    CategoryID: int
 
 
class UpdateEventCategoryInfoRequest(BaseModel):
    EventCategoryID: int
    EventID: int
    CategoryID: int
 
 
# ---------- eventorganizerInfo ----------
class AddEventOrganizerInfoRequest(BaseModel):
    EventOrganizerName: str
    EventOrganizerLogoPath: str
    CreatedByAccountID: int
    EventOrganizerDiscription: Optional[str] = None
 
 
class UpdateEventOrganizerInfoRequest(BaseModel):
    EventOrganizerID: int
    EventOrganizerName: str
    EventOrganizerLogoPath: str
    CreatedByAccountID: int
    EventOrganizerDiscription: Optional[str] = None
 
 
# ---------- organizermember ----------
class AddOrganizerMemberRequest(BaseModel):
    AccountID: int
    EventOrganizerID: int
    TeamRoleID: int
 
 
class UpdateOrganizerMemberRequest(BaseModel):
    MemberID: int
    AccountID: int
    EventOrganizerID: int
    TeamRoleID: int
 
 
# ---------- eventRole ----------
class AddEventRoleRequest(BaseModel):
    RoleName: str
 
 
class UpdateEventRoleRequest(BaseModel):
    EventRoleID: int
    RoleName: str
 
 
# ---------- eventstaff ----------
class AddEventStaffRequest(BaseModel):
    EventID: int
    MemberID: int
    EventRoleID: int
    AssignedAtYMDT: Optional[datetime] = None
 
 
class UpdateEventStaffRequest(BaseModel):
    AssignmentID: int
    EventID: int
    MemberID: int
    EventRoleID: int
    AssignedAtYMDT: Optional[datetime] = None
 
 
# ---------- paymenttypeinfo ----------
class AddPaymentTypeInfoRequest(BaseModel):
    PaymentTypeName: str
 
 
class UpdatePaymentTypeInfoRequest(BaseModel):
    PaymentTypeID: int
    PaymentTypeName: str
 
 
# ---------- ordersinfo ----------
class AddOrdersInfoRequest(BaseModel):
    AccountID: int
    PaymentTypeID: int
    PaymentDateYMDT: Optional[datetime] = None
    ProveOfPayment: Optional[str] = None
 
 
class UpdateOrdersInfoRequest(BaseModel):
    OrderID: int
    AccountID: int
    PaymentTypeID: int
    PaymentDateYMDT: Optional[datetime] = None
    ProveOfPayment: Optional[str] = None
 
 
# ---------- ticketattendence ----------
class AddTicketAttendenceRequest(BaseModel):
    TicketTypeID: int
    OrderID: int
    FirstName: str
    LastName: str
    PhoneNum: str
    Email: str
 
 
class UpdateTicketAttendenceRequest(BaseModel):
    attendeeID: int
    TicketTypeID: int
    OrderID: int
    FirstName: str
    LastName: str
    PhoneNum: str
    Email: str

 # ---------- teamrole ----------
class AddTeamRoleRequest(BaseModel):
    TeamRoleName: str
 
 
class UpdateTeamRoleRequest(BaseModel):
    TeamRoleID: int
    TeamRoleName: str
 
 
# ---------- verifactiontypeinfo ----------
class AddVerificationTypeInfoRequest(BaseModel):
    IDType: str
 
 
class UpdateVerificationTypeInfoRequest(BaseModel):
    VerificationTypeID: int
    IDType: str
 
 
# ---------- Verificationstatusinfo ----------
class AddVerificationStatusInfoRequest(BaseModel):
    StatusName: str
 
 
class UpdateVerificationStatusInfoRequest(BaseModel):
    VerificationStatusID: int
    StatusName: str
 
 
# ---------- identityverifcation ----------
class AddIdentityVerificationRequest(BaseModel):
    AccountID: int
    VerificationTypeID: int
    IDNumberEncrypted: str
    FullNameOnID: str
    DateOfBirth: Optional[date] = None
    DocumentImageRedPath: Optional[str] = None
    VerificationStatusID: int
    ReviewedByAccountID: Optional[int] = None
    SubmittedAtYMDT: Optional[datetime] = None
    ReviewedAtYMDT: Optional[datetime] = None
 
 
class UpdateIdentityVerificationRequest(BaseModel):
    VerificationID: int
    AccountID: int
    VerificationTypeID: int
    IDNumberEncrypted: str
    FullNameOnID: str
    DateOfBirth: Optional[date] = None
    DocumentImageRedPath: Optional[str] = None
    VerificationStatusID: int
    ReviewedByAccountID: Optional[int] = None
    SubmittedAtYMDT: Optional[datetime] = None
    ReviewedAtYMDT: Optional[datetime] = None
 
 
# ---------- attendeeresponse ----------
class AddAttendeeResponseRequest(BaseModel):
    EventQuestionID: int
    attendeeID: int
    attendeeAnswer: str
 
 
class UpdateAttendeeResponseRequest(BaseModel):
    ResponseID: int
    EventQuestionID: int
    attendeeID: int
    attendeeAnswer: str

# ---------- accountstatusinfo ----------
class AddAccountStatusInfoRequest(BaseModel):
    StatusType: str
 
 
class UpdateAccountStatusInfoRequest(BaseModel):
    StatusID: int
    StatusType: str

# ---------- AccountInfo ----------
class AddAccountInfoRequest(BaseModel):
    FirstName: str
    LastName: str
    PhoneNum: str
    Email: str
    StatusID: int
    PasswordEnc : str
 
 
class UpdateAccountNoPasswordInfoRequest(BaseModel):
    AccountID: int
    FirstName: str
    LastName: str
    PhoneNum: str
    Email: str
    StatusID: int

 # ---------- wishlistinfo ----------
class AddWishlistRequest(BaseModel):
    AccountID: int
    EventID: int


# ---------- accountcategoryinfo ----------
class SetAccountCategoriesRequest(BaseModel):
    AccountID: int
    CategoryIDs: List[int]

class AddAccountCategoryRequest(BaseModel):
    AccountID: int
    CategoryID: int
