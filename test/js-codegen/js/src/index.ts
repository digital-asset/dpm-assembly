/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import type {components, paths} from '../js-generated/api/ledger-api';
import {Main} from '../js-generated/myproject-main-1.0.0';
import createClient from 'openapi-fetch';

export const client = createClient<paths>({baseUrl: "http://localhost:6864"});

function valueOrError<T>(response: { data?: T, error?: any }): Promise<T> {
  if (response.data === undefined) {
    console.log(`Error ${JSON.stringify(response.error)}`)
    return Promise.reject(response.error);
  } else {
    return Promise.resolve(response.data);
  }
}

async function test() {
  console.log("Starting test");
  const allocatePartyResp = await client.POST("/v2/parties", {
    body: {
      partyIdHint: "Alice",
      identityProviderId: "",
      synchronizerId: "",
      userId: "",
    }
  });
  const alice: string = await valueOrError(allocatePartyResp).then(data => data.partyDetails!?.party);
  console.log("Allocated Alice: " + alice);

  const iou: Main.IOU = {
    issuer: alice,
    owner: alice,
    value: "10",
    name: "USDT"
  };

  const createCommand: components["schemas"]["CreateCommand"] = {
    createArguments: iou,
    templateId: Main.IOU.templateId
  };

  const createResp = await client.POST("/v2/commands/submit-and-wait", {
    body: {
      commands: [{CreateCommand: createCommand}],
      commandId: (Math.random() + 1).toString(36).substring(7),
      userId: "ledger-api-user",
      actAs: [alice],
      readAs: [alice],
    }
  }); 
  console.log("Created contract: " + JSON.stringify(await valueOrError(createResp)));

  const ledgerEndResp = await client.GET("/v2/state/ledger-end");
  const ledgerEnd = (await valueOrError(ledgerEndResp)).offset!;

  const queryResp = await client.POST("/v2/state/active-contracts", {
    body: {
      eventFormat: {
        filtersByParty: {
          [alice]: {}
        },
        verbose: false
      },
      activeAtOffset: ledgerEnd,
    } as components["schemas"]["GetActiveContractsRequest"]
  });
  const activeContracts = await valueOrError(queryResp);
  if (activeContracts.length != 1) throw new Error("Incorrect number of active contracts");
  const contract = (activeContracts[0].contractEntry! as {JsActiveContract: components["schemas"]["JsActiveContract"]}).JsActiveContract;
  const queriedAsset = contract.createdEvent.createArgument as Main.IOU;
  if (queriedAsset.issuer != alice) throw new Error("Alice wasn't the owner of the contract");
  console.log("Successfully queried correct contract.");
}

test();
