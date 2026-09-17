CREATE TABLE IF NOT EXISTS accountcategoryinfo (
    AccountCategoryID INT AUTO_INCREMENT PRIMARY KEY,
    AccountID INT NOT NULL,
    CategoryID INT NOT NULL,
    CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_account_category (AccountID, CategoryID),
    FOREIGN KEY (AccountID) REFERENCES accountinfo(AccountID) ON DELETE CASCADE,
    FOREIGN KEY (CategoryID) REFERENCES categoryinfo(CategoryID) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS wishlistinfo (
    WishID INT AUTO_INCREMENT PRIMARY KEY,
    AccountID INT NOT NULL,
    EventID INT NOT NULL,
    CreatedAtYMDT DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_account_event (AccountID, EventID),
    FOREIGN KEY (AccountID) REFERENCES accountinfo(AccountID) ON DELETE CASCADE,
    FOREIGN KEY (EventID) REFERENCES eventinfo(EventID) ON DELETE CASCADE
);
