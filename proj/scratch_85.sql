select l1_0.id,
       l1_0.address_id,
       l1_0.alternative_warehouse_code,
       l1_0.company_id,
       l1_0.is_crop_location,
       l1_0.date_created,
       l1_0.date_modified,
       l1_0.email,
       l1_0.fence_id,
       l1_0.has_worker,
       l1_0.last_warehouse_job_creation_date,
       l1_0.location_code,
       l1_0.location_name,
       l1_0.location_type,
       l1_0.phone,
       l1_0.primary_contact_id,
       l1_0.scrap_warehouse,
       l1_0.status,
       a1_0.id,
       a1_0.administrative_area_level_1,
       a1_0.administrative_area_level_2,
       a1_0.country,
       a1_0.country_code,
       a1_0.date_created,
       a1_0.date_modified,
       a1_0.formatted_address,
       a1_0.full_address,
       a1_0.latitude,
       a1_0.locality,
       a1_0.longitude,
       a1_0.place_id,
       a1_0.postal_code,
       a1_0.premise,
       a1_0.room,
       a1_0.route,
       a1_0.street_number,
       c1_0.id,
       c1_0.approver_id,
       c1_0.bank_account_number,
       c1_0.bank_account_number_missing_reason,
       c1_0.bank_swift_code,
       c1_0.company_type,
       c1_0.credit,
       c1_0.customer_manager_id,
       c1_0.date_created,
       c1_0.date_modified,
       c1_0.deleted,
       c1_0.in_credit_risk_management,
       c1_0.name,
       c1_0.nav_customer_id,
       c1_0.nav_vendor_id,
       c1_0.is_problematic,
       c1_0.reg_no,
       c1_0.review_cause,
       c1_0.status,
       c1_0.used,
       c1_0.vat_reg_no,
       c1_0.vat_reg_no_missing,
       p1_0.name,
       array_agg(tl1_0.id) filter (where tl1_0.id is not null),
       array_agg(tl1_0.location_name) filter (where tl1_0.location_name is not null),
       array_agg(fd1_0.distance_in_kilometres) filter (where fd1_0.distance_in_kilometres is not null),
       array_agg(fl1_0.id) filter (where fl1_0.id is not null),
       array_agg(fl1_0.location_name) filter (where fl1_0.location_name is not null),
       array_agg(td1_0.distance_in_kilometres) filter (where td1_0.distance_in_kilometres is not null),
       c1_0.id in
       (cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint),
        cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint)) and sum(case l2_0.is_crop_location when true then 1 when false then 0 else null end) = cast(? as integer),
       c1_0.id in
       (cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint),
        cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint)) and array_agg(tl1_0.id) filter (where tl1_0.id is not null) is null and array_agg(fl1_0.id) filter (where fl1_0.id is not null) is null,
       l1_0.is_crop_location in (cast(? as boolean)) and array_agg(tl1_0.id) filter (where tl1_0.id is not null) is null and array_agg(fl1_0.id) filter (where fl1_0.id is not null) is null,
       array_agg(p2_0.name order by p2_0.name) filter (where p2_0.name is not null),
       c1_0.id in
       (cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint),
        cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint), cast(? as bigint))
from locations l1_0
         left join addresses a1_0 on a1_0.id = l1_0.address_id
         join companies c1_0 on c1_0.id = l1_0.company_id
         left join representatives cm1_0 on cm1_0.id = c1_0.customer_manager_id
         left join persons p1_0 on p1_0.id = cm1_0.person_id
         left join company_has_customer_manager cm2_0 on c1_0.id = cm2_0.company_id
         left join representatives cm2_1 on cm2_1.id = cm2_0.representative_id
         left join persons p2_0 on p2_0.id = cm2_1.person_id
         join locations l2_0 on c1_0.id = l2_0.company_id and l2_0.status in (?)
         left join distance fd1_0 on l1_0.id = fd1_0.from_location_id
         left join locations tl1_0 on tl1_0.id = fd1_0.to_location_id
         left join distance td1_0 on l1_0.id = td1_0.to_location_id
         left join locations fl1_0 on fl1_0.id = td1_0.from_location_id
where c1_0.status in (?, ?)
  and l1_0.status in (?)
  and c1_0.id not in (?)
  and 1 = 1
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59
having (c1_0.id in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) and sum(case l2_0.is_crop_location when true then 1 when false then 0 else null end) =? or c1_0.id in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) and array_agg(tl1_0.id) filter (where tl1_0.id is not null) is null and array_agg(fl1_0.id) filter (where fl1_0.id is not null) is null or l1_0.is_crop_location in (?) and array_agg(tl1_0.id) filter (where tl1_0.id is not null) is null and array_agg(fl1_0.id) filter (where fl1_0.id is not null) is null)
order by l1_0.date_created desc nulls last
offset ? rows fetch first ? rows only