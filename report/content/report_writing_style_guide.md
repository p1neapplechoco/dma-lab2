# Style Guide Viet Report Data Mining Lab1

Muc tieu cua tai lieu nay la chuan hoa cach viet bao cao theo phong cach da dung trong phan temporal va tabular preprocessing: ro rang, co bang chung, co ham y cho pipeline.

## 1) Nguyen tac cot loi

1. Evidence first, claim later.
2. Moi nhan xet quan trong phai co bang chung tu hinh, bang, hoac chi so.
3. Moi subsection EDA phai ket bang mot quyet dinh cho buoc preprocessing/modeling tiep theo.
4. Giu nhat quan thuat ngu trong toan report.
5. Uu tien so cu the, moc thoi gian cu the, tham so cu the.

## 2) Cong thuc viet cho moi subsection

Viet moi subsection theo 5 cau:

1. Muc tieu phan tich:
   - Doan nay nham kiem tra dieu gi?
2. Thiet lap ky thuat:
   - Dung ky thuat nao, tham so nao, vi sao tham so do hop ly voi domain?
3. Quan sat chinh:
   - Neu 2-3 tin hieu ro rang nhat, kem so lieu neu co.
4. Dien giai thong ke:
   - Tin hieu do ham y gi ve trend, seasonality, autocorrelation, stationarity?
5. Ham y pipeline:
   - Can tao feature nao, bien doi nao, kiem dinh nao o buoc tiep theo?

## 3) Khung viet cho Time Plot

Thu tu trinh bay khuyen nghi:

1. Toan giai doan:
   - Co xu huong dai han hay khong?
   - Co nhin thay mua vu nam hay khong?
2. Zoom ngan han (tuan/ngay):
   - Chu ky ngay 24h va chu ky tuan co ro khong?
   - Co bat thuong theo holiday/weekend khong?
3. Tong ket cau truc chuoi:
   - Trend, seasonality, noise/holiday effects.
4. Ket luan stationarity so bo:
   - Mean va/hoac variance co thay doi theo thoi gian khong?

Mau cau ket thuc Time Plot:

- Tu cac quan sat tren, chuoi the hien mua vu da cap ngay-tuan-nam va mean bien thien theo pha mua vu, do do chua dat dieu kien dung de mo hinh hoa truc tiep.

## 4) Khung viet cho ACF va PACF

Thu tu trinh bay khuyen nghi:

1. Neu lag mac dinh theo cong thuc.
2. Neu ly do mo rong lag theo domain (vi du du lieu hourly can kiem tra 24h va 168h).
3. Doc ACF:
   - Giam cham hay nhanh?
   - Co dinh lap lai o boi so chu ky khong?
4. Doc PACF:
   - Spike o lag nao noi bat?
   - Ham y anh huong truc tiep ngan han den muc nao?
5. Chot ham y feature engineering:
   - Lag ngan han bat buoc (t-1, t-2, t-3).
   - Lag mua vu bat buoc (t-24, co the t-168 tuy bai toan).

Mau cau ket thuc ACF/PACF:

- Ket qua ACF/PACF ung ho viec dua cac lag ngan han va lag mua vu vao ma tran dac trung, dong thoi can ap dung cac phep bien doi lam dung truoc khi huan luyen mo hinh du bao.

## 5) Khung viet cho Rolling Statistics

Thu tu trinh bay khuyen nghi:

1. Neu ro cua so rolling va quy doi ve gio/ngay.
2. Nhan xet rolling mean khi cua so tang.
3. Nhan xet rolling std khi cua so tang.
4. Ket luan co vi pham dieu kien dung hay khong.
5. De xuat bien doi tiep theo:
   - On dinh variance (log/Box-Cox).
   - On dinh mean (differencing/decomposition).

## 6) Quy tac dinh luong bat buoc

1. Uu tien ghi so lieu cu the thay vi mo ta mo ho.
2. Neu noi thay doi lon, nen neu muc chenh (ti le, khoang, p-value, RMSE, F1, ...).
3. Moi ket luan quan trong nen co it nhat 1 bang chung:
   - Hoac chi so thong ke.
   - Hoac hinh minh hoa co caption ro.

## 7) Quy tac trinh bay hinh, bang, va tham chieu

1. Moi hinh/bang phai co caption noi dung day du.
2. Trong van ban phai refer toi hinh/bang bang nhan, khong noi chung chung.
3. Ten bien trong dataset dat nghieng de nhat quan.
4. Cong thuc va ky hieu can giu dong bo giua cac section.

## 7.1) Quy tac hinh cho project nay

1. Uu tien dung hinh lay truc tiep tu output cua notebook.
2. Khong tu tao hinh moi neu notebook da co hinh tuong duong.
3. Ten file hinh nen phan anh dung noi dung phan tich (vi du: stl_decomposition_168h, granger_heatmap_lag3).
4. Moi hinh chen vao report phai co 3 thanh phan:
   - \\includegraphics
   - \\caption
   - \\label
5. Trong doan van truoc/sau hinh phai co cau dan den nhan hinh (Hinh \\ref{...}).

## 7.2) Quy tac trich dan tai lieu

1. Su dung \\cite{...} thong nhat trong toan report.
2. Moi ky thuat chinh nen co it nhat 1 nguon hoc thuat goc.
3. Co the bo sung 1 nguon tai lieu cong cu (statsmodels/scipy/sklearn docs) de lien he trien khai.
4. Tranh trich dan trang tong hop khong on dinh khi da co bai bao goc.
5. Kiem tra key trong ref.bib truoc khi chen cite de tranh loi build.

## 8) Checklist truoc khi chot moi subsection

1. Da co cau mo dau neu muc tieu?
2. Da co tham so ky thuat cu the?
3. Da co 2-3 quan sat chinh co bang chung?
4. Da co dien giai thong ke?
5. Da co cau ket noi sang buoc preprocessing/modeling tiep theo?
6. Da nhat quan thuat ngu voi cac section truoc?
7. Da chen \\cite cho ky thuat/kiem dinh quan trong?
8. Hinh minh hoa co xuat phat tu notebook va da co \\label?

## 8.1) Checklist rieng cho phan Ket luan temporal

1. Tom tat ro cac buoc pipeline da lam.
2. Nhac ro cach danh gia: du bao mot buoc truoc (t+1).
3. Neu so lieu tong ket hieu nang chinh (MAE, RMSE).
4. Co muc han che (limitations) toi thieu 3 y:
   - Pham vi bai toan (one-step vs multi-step)
   - Gioi han mo hinh/so sanh mo hinh
   - Gioi han du lieu va bien ngoai sinh

## 9) Mau skeleton copy nhanh

### [Ten subsection]

Doan nay nham [muc tieu].

Nhom su dung [ky thuat] voi [tham so], vi [ly do domain/du lieu].

Ket qua cho thay [quan sat 1], [quan sat 2], va [quan sat 3 neu co].

Cac dau hieu nay ham y [dien giai thong ke: trend/seasonality/autocorrelation/stationarity].

Tu do, o buoc tiep theo can [ham y tien xu ly: feature lag, bien doi, kiem dinh, decomposition, ...].

## 10) Mau skeleton cho Ket luan temporal

Pipeline cuoi cung gom [cac buoc chinh theo thu tu].

Pipeline duoc danh gia bang bai toan du bao mot buoc truoc ($t+1$), dat [chi so MAE/RMSE].

Ket qua cho thay [diem manh chinh].

Han che hien tai gom: [han che 1], [han che 2], [han che 3].

---

Goi y su dung nhanh:

- Khi viet xong moi subsection, doc lai 1 lan va thu xoa toan bo tinh tu mo ta.
- Neu doan van van dung duoc va van ro nghia, subsection da dat chat luong hoc thuat tot.
