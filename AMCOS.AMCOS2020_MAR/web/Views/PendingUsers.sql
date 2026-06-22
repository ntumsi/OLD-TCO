CREATE VIEW web.PendingUsers
AS
SELECT u.UserId + ',' + u.FirstName + ' ' + ISNULL(u.MiddleName + '', '') + u.LastName + ',' + u.Email AS UserInfo,
       u.FirstName + ' ' + ISNULL(u.MiddleName + '', '') + u.LastName AS UserName,
       u.Email AS UserEmail,
       u.ComPhone AS UserPhone,
       u.OfficeName AS UserOfficeName,
       u.Macom AS UserMacom,
       u.SelfAccountType AS UserAccountType,
       u.ArmyRank AS UserArmyRank,
       u.CompanyName AS UserCompanyName,
       u.LastLogin AS UserLastLogin,
       SponsorName = CASE u.SelfAccountType
                         WHEN 'MILITARY' THEN
                             NULL
                         WHEN 'CIVILIAN' THEN
                             NULL
                         WHEN 'CONTRACTOR' THEN
                             s.FirstName + ' ' + ISNULL(s.MiddleName + '', '') + s.LastName
                         WHEN 'OTHER' THEN
                             s.FirstName + ' ' + ISNULL(s.MiddleName + '', '') + s.LastName
                         ELSE
                             s.FirstName + ' ' + ISNULL(s.MiddleName + '', '') + s.LastName
                     END,
       SponsorEmail = CASE u.SelfAccountType
                          WHEN 'MILITARY' THEN
                              NULL
                          WHEN 'CIVILIAN' THEN
                              NULL
                          WHEN 'CONTRACTOR' THEN
                              s.Email
                          WHEN 'OTHER' THEN
                              s.Email
                          ELSE
                              s.Email
                      END,
       SponsorPhone = CASE u.SelfAccountType
                          WHEN 'MILITARY' THEN
                              NULL
                          WHEN 'CIVILIAN' THEN
                              NULL
                          WHEN 'CONTRACTOR' THEN
                              s.ComPhone
                          WHEN 'OTHER' THEN
                              s.ComPhone
                          ELSE
                              s.ComPhone
                      END,
       SponsorOfficeName = CASE u.SelfAccountType
                               WHEN 'MILITARY' THEN
                                   NULL
                               WHEN 'CIVILIAN' THEN
                                   NULL
                               WHEN 'CONTRACTOR' THEN
                                   s.OfficeName
                               WHEN 'OTHER' THEN
                                   s.OfficeName
                               ELSE
                                   s.OfficeName
                           END,
       SponsorMacom = CASE u.SelfAccountType
                          WHEN 'MILITARY' THEN
                              NULL
                          WHEN 'CIVILIAN' THEN
                              NULL
                          WHEN 'CONTRACTOR' THEN
                              s.Macom
                          WHEN 'OTHER' THEN
                              s.Macom
                          ELSE
                              s.Macom
                      END,
       SponsorAccountType = CASE u.SelfAccountType
                                WHEN 'MILITARY' THEN
                                    NULL
                                WHEN 'CIVILIAN' THEN
                                    NULL
                                WHEN 'CONTRACTOR' THEN
                                    s.SelfAccountType
                                WHEN 'OTHER' THEN
                                    s.SelfAccountType
                                ELSE
                                    s.SelfAccountType
                            END,
       SponsorArmyRank = CASE u.SelfAccountType
                             WHEN 'MILITARY' THEN
                                 NULL
                             WHEN 'CIVILIAN' THEN
                                 NULL
                             WHEN 'CONTRACTOR' THEN
                                 s.ArmyRank
                             WHEN 'OTHER' THEN
                                 s.ArmyRank
                             ELSE
                                 s.ArmyRank
                         END,
       u.UserStatus AS UserStatus
FROM webuser.AMCOSUser u
    LEFT JOIN webuser.AMCOSUser s
        ON u.SponsorUserId = s.UserId
WHERE u.UserStatus LIKE 'Pending%';