import React from 'react';
import { Composition } from 'remotion';
import { RankingShort, rankingDuration } from './templates/RankingShort';
import { ProblemSolveShort, problemSolveDuration } from './templates/ProblemSolveShort';
import { VersusShort, versusDuration } from './templates/VersusShort';
import { ensureFonts } from './fonts';
import { FPS, W, H } from './theme';
import type { ProblemSolveProps, RankingProps, VersusProps } from './types';
import deskTop5 from './data/desk-top5.json';
import deskProblem from './data/desk-problem.json';
import deskVersus from './data/desk-versus.json';

ensureFonts();

/**
 * 포맷 3종을 같은 상품 데이터로 돌려보고, 어느 게 도는지 2주 안에 가린다.
 * 이긴 포맷 하나만 남기고 나머지는 버리는 게 이 프로젝트의 목적이다.
 */
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="Ranking"
        component={RankingShort}
        fps={FPS}
        width={W}
        height={H}
        defaultProps={deskTop5 as RankingProps}
        // 상품 개수가 바뀌면 영상 길이도 따라 바뀐다.
        calculateMetadata={({ props }) => ({
          durationInFrames: rankingDuration(props.items.length),
        })}
      />
      <Composition
        id="ProblemSolve"
        component={ProblemSolveShort}
        fps={FPS}
        width={W}
        height={H}
        defaultProps={deskProblem as ProblemSolveProps}
        calculateMetadata={({ props }) => ({
          durationInFrames: problemSolveDuration(props.items.length),
        })}
      />
      <Composition
        id="Versus"
        component={VersusShort}
        fps={FPS}
        width={W}
        height={H}
        durationInFrames={versusDuration()}
        defaultProps={deskVersus as VersusProps}
      />
    </>
  );
};
