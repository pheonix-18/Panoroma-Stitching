location = './mov3';
ds = imageDatastore(location);
indices = 4:7;

subimds = subset(ds, indices);
% montage(subimds);

I1 = rgb2gray(readimage(subimds,1));
I2 = rgb2gray(readimage(subimds,2));

points1 = detectHarrisFeatures(I1);
points2 = detectHarrisFeatures(I2);

[f1, vpts1] = extractFeatures(I1, points1);
[f2, vpts2] = extractFeatures(I2, points2);

indexPairs = matchFeatures(f1, f2) ;
matchedPoints1 = vpts1(indexPairs(:, 1)).Location
matchedPoints2 = vpts2(indexPairs(:, 2)).Location


[H, inliners] = ransacfithomography(matchedPoints1', matchedPoints2', 0.001)
